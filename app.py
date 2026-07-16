import os
import csv
import io
import json
import base64
import zipfile
import secrets
import smtplib
import jwt
import psycopg2
from psycopg2.extras import RealDictCursor
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from pathlib import Path
from flask import Flask, request, jsonify, send_from_directory, send_file, redirect
from flask_cors import CORS
from functools import wraps
from werkzeug.security import check_password_hash, generate_password_hash

BASE_DIR = Path(__file__).parent

# Load environment variables from .env file if python-dotenv is installed
try:
    from dotenv import load_dotenv
    load_dotenv(BASE_DIR / '.env')
except Exception:
    pass

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', os.urandom(32).hex())
app.config.update(
    MAX_CONTENT_LENGTH=16 * 1024 * 1024,
)

CORS_ORIGINS = os.environ.get('CORS_ORIGINS', '*').split(',')
CORS(app, origins=CORS_ORIGINS, supports_credentials=True)

JWT_SECRET = os.environ.get('JWT_SECRET', os.urandom(32).hex())
JWT_ALGORITHM = 'HS256'
JWT_EXPIRY_HOURS = 24


@app.after_request
def set_security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['Referrer-Policy'] = 'same-origin'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    return response

DATABASE_URL = os.environ.get('DATABASE_URL', '')
DEFAULT_RECEIPTS_DIR = BASE_DIR / 'receipts'
BACKUP_DIR = BASE_DIR / 'backups'

DEFAULT_RECEIPTS_DIR.mkdir(parents=True, exist_ok=True)
BACKUP_DIR.mkdir(parents=True, exist_ok=True)

PORT = int(os.environ.get('PORT', '5001'))
SMTP_HOST = os.environ.get('SMTP_HOST', 'smtp.gmail.com')
SMTP_PORT = int(os.environ.get('SMTP_PORT', 587))
SMTP_USER = os.environ.get('SMTP_USER', '')
SMTP_PASSWORD = os.environ.get('SMTP_PASSWORD', '')
RESET_EMAIL_RECIPIENT = os.environ.get('RESET_EMAIL_RECIPIENT', 'amieecompany@gmail.com')
APP_BASE_URL = os.environ.get('APP_BASE_URL', f'http://127.0.0.1:{PORT}')
if '127.0.0.1:' in APP_BASE_URL or 'localhost:' in APP_BASE_URL:
    APP_BASE_URL = f'http://127.0.0.1:{PORT}'

MAX_LOGIN_ATTEMPTS = 3
LOGIN_LOCKOUT_MINUTES = 5

DEFAULT_SETTINGS = {
    'company_name': 'Parking Manager',
    'company_address': '',
    'company_phone': '',
    'company_email': '',
    'company_reg_no': '',
    'bank_account': '',
    'receipt_title': 'PAYMENT RECEIPT',
    'receipt_footer': 'Thank you for your payment.',
    'rate_per_hour': '2.00',
    'company_logo': '',
    'company_qr_code': '',
    'receipts_base_path': str(DEFAULT_RECEIPTS_DIR)
}

DEFAULT_USERS = [
    {'username': 'admin', 'password': 'admin', 'role': 'admin', 'name': 'Administrator'},
    {'username': 'manager', 'password': 'manager', 'role': 'manager', 'name': 'Manager'}
]

MONTHLY_PLANS = ['Bulanan Parking', 'Bulanan + Transport', 'Berbumbung', 'Berbumbung + Transport']
DAILY_PLANS = ['Harian Parking', 'Harian + Transport', 'Transport Sahaja']


def get_db():
    if not DATABASE_URL:
        raise RuntimeError('DATABASE_URL environment variable is not set. Please configure your PostgreSQL connection string.')
    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = False
    return conn


def create_jwt_token(user):
    payload = {
        'user_id': user['id'],
        'username': user['username'],
        'role': user['role'],
        'name': user['name'],
        'exp': datetime.utcnow() + timedelta(hours=JWT_EXPIRY_HOURS)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_jwt_token(token):
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None


def get_current_user():
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        token = auth_header[7:]
        payload = decode_jwt_token(token)
        if payload:
            return payload
    return None


def init_db():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS receipts (
            id SERIAL PRIMARY KEY,
            receipt_number TEXT NOT NULL UNIQUE,
            customer_name TEXT NOT NULL,
            phone TEXT,
            vehicle_number TEXT NOT NULL,
            slot_code TEXT,
            entry_time TEXT,
            exit_time TEXT,
            duration_minutes INTEGER DEFAULT 0,
            rate_per_hour REAL DEFAULT 0,
            amount REAL DEFAULT 0,
            payment_method TEXT DEFAULT 'Cash',
            plan TEXT DEFAULT 'Harian Parking',
            status TEXT DEFAULT 'Pending',
            notes TEXT,
            file_path TEXT,
            file_data TEXT,
            source TEXT DEFAULT 'System',
            created_by INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            username TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'manager',
            name TEXT,
            active INTEGER DEFAULT 1,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
            id SERIAL PRIMARY KEY,
            user_id INTEGER,
            username TEXT,
            action TEXT NOT NULL,
            details TEXT,
            ip_address TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS login_attempts (
            id SERIAL PRIMARY KEY,
            username TEXT,
            ip_address TEXT,
            success INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS customers (
            id SERIAL PRIMARY KEY,
            customer_name TEXT NOT NULL,
            phone TEXT,
            vehicle_number TEXT NOT NULL UNIQUE,
            plan TEXT DEFAULT 'Harian Parking',
            status TEXT DEFAULT 'Pending',
            start_date TEXT,
            end_date TEXT,
            monthly_rate REAL DEFAULT 0,
            transport_included INTEGER DEFAULT 0,
            notes TEXT,
            last_payment_date TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS password_reset_tokens (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL,
            token TEXT NOT NULL UNIQUE,
            expiry TEXT NOT NULL,
            used INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS history_records (
            id SERIAL PRIMARY KEY,
            customer_id INTEGER,
            customer_name TEXT,
            vehicle_number TEXT,
            phone TEXT,
            plan TEXT,
            monthly_rate REAL,
            start_date TEXT,
            end_date TEXT,
            notes TEXT,
            terminated_by INTEGER,
            terminated_by_name TEXT,
            terminated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS transport_customers (
            id SERIAL PRIMARY KEY,
            zone TEXT NOT NULL,
            customer_name TEXT NOT NULL,
            phone TEXT,
            package TEXT NOT NULL,
            pax INTEGER DEFAULT 1,
            amount REAL DEFAULT 0,
            status TEXT DEFAULT 'Active',
            start_date TEXT,
            end_date TEXT,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
            id SERIAL PRIMARY KEY,
            key TEXT NOT NULL UNIQUE,
            value TEXT
        )
    ''')
    conn.commit()
    cursor.close()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT COUNT(*) as count FROM users')
    if cursor.fetchone()['count'] == 0:
        for user in DEFAULT_USERS:
            cursor.execute('''
                INSERT INTO users (username, password_hash, role, name)
                VALUES (%s, %s, %s, %s)
            ''', (user['username'], generate_password_hash(user['password']), user['role'], user['name']))
        conn.commit()
    for user in DEFAULT_USERS:
        cursor.execute('SELECT id FROM users WHERE username = %s', (user['username'],))
        if not cursor.fetchone():
            cursor.execute('''
                INSERT INTO users (username, password_hash, role, name)
                VALUES (%s, %s, %s, %s)
            ''', (user['username'], generate_password_hash(user['password']), user['role'], user['name']))
            conn.commit()
    cursor.execute("UPDATE users SET role = 'manager', name = COALESCE(NULLIF(name, ''), 'Manager') WHERE role = 'cashier'")
    conn.commit()
    cursor.close()
    conn.close()


def row_to_dict(row):
    if isinstance(row, dict):
        return dict(row)
    return {key: row[key] for key in row.keys()}


def sync_customer_from_receipt(receipt):
    try:
        conn = get_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT id FROM customers WHERE vehicle_number = %s', (receipt['vehicle_number'],))
        existing = cursor.fetchone()
        transport_included = 1 if receipt['plan'] in ['Harian + Transport', 'Bulanan + Transport', 'Berbumbung + Transport', 'Transport Sahaja'] else 0
        is_monthly = receipt['plan'] in MONTHLY_PLANS
        today = datetime.now().strftime('%Y-%m-%d')
        if existing:
            cursor.execute('''
                UPDATE customers SET
                    customer_name = %s, phone = %s, plan = %s, status = %s,
                    transport_included = %s, last_payment_date = %s, updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
            ''', (
                receipt['customer_name'],
                receipt.get('phone', ''),
                receipt['plan'],
                'Active',
                transport_included,
                receipt.get('created_at', today),
                existing['id']
            ))
            if is_monthly:
                start_date = receipt.get('created_at', today)[:10]
                end_date = (datetime.strptime(start_date, '%Y-%m-%d') + timedelta(days=30)).strftime('%Y-%m-%d')
                cursor.execute('UPDATE customers SET start_date = %s, end_date = %s, monthly_rate = %s WHERE id = %s',
                               (start_date, end_date, receipt.get('amount', 0), existing['id']))
        else:
            start_date = receipt.get('created_at', today)[:10]
            end_date = None
            monthly_rate = 0
            if is_monthly:
                end_date = (datetime.strptime(start_date, '%Y-%m-%d') + timedelta(days=30)).strftime('%Y-%m-%d')
                monthly_rate = receipt.get('amount', 0)
            cursor.execute('''
                INSERT INTO customers (
                    customer_name, phone, vehicle_number, plan, status, start_date, end_date,
                    monthly_rate, transport_included, notes, last_payment_date
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ''', (
                receipt['customer_name'],
                receipt.get('phone', ''),
                receipt['vehicle_number'],
                receipt['plan'],
                'Active',
                start_date,
                end_date,
                monthly_rate,
                transport_included,
                receipt.get('notes', ''),
                receipt.get('created_at', today)
            ))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception:
        pass


def log_audit(action, details=None):
    try:
        user = get_current_user()
        user_id = user.get('user_id') if user else None
        username = user.get('username') if user else None
        ip = request.remote_addr
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO audit_logs (user_id, username, action, details, ip_address)
            VALUES (%s, %s, %s, %s, %s)
        ''', (user_id, username, action, json.dumps(details) if details else None, ip))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception:
        pass


def send_reset_email(username, reset_link):
    try:
        if not all([SMTP_HOST, SMTP_USER, SMTP_PASSWORD]):
            print(f'[EMAIL FALLBACK] SMTP not configured. Reset link for {username}: {reset_link}')
            return False
        msg = MIMEMultipart()
        msg['From'] = SMTP_USER
        msg['To'] = RESET_EMAIL_RECIPIENT
        msg['Subject'] = 'Permintaan Reset Kata Laluan - Parking Manager'
        body = f"""Assalamualaikum,

Ada permintaan reset kata laluan untuk akaun berikut:

Username: {username}
Link Reset: {reset_link}

Sila klik link di atas untuk set kata laluan baharu. Link ini sah untuk 1 jam sahaja.

Jika anda tidak membuat permintaan ini, abaikan email ini.

Terima kasih,
Parking Manager
"""
        msg.attach(MIMEText(body, 'plain'))
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
        print(f'[EMAIL SENT] Reset link for {username} sent to {RESET_EMAIL_RECIPIENT}')
        return True
    except Exception as e:
        print(f'[EMAIL ERROR] {e}')
        print(f'[EMAIL FALLBACK] Reset link for {username}: {reset_link}')
        return False


def is_locked_out(username, ip):
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    since = (datetime.now() - timedelta(minutes=LOGIN_LOCKOUT_MINUTES)).isoformat()
    cursor.execute('''
        SELECT COUNT(*) as attempts FROM login_attempts
        WHERE username = %s AND ip_address = %s AND success = 0 AND created_at > %s
    ''', (username, ip, since))
    attempts = cursor.fetchone()['attempts']
    cursor.close()
    conn.close()
    return attempts >= MAX_LOGIN_ATTEMPTS


def record_login_attempt(username, ip, success):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO login_attempts (username, ip_address, success)
        VALUES (%s, %s, %s)
    ''', (username, ip, 1 if success else 0))
    conn.commit()
    cursor.close()
    conn.close()


def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        user = get_current_user()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
        return f(*args, **kwargs)
    return decorated_function


def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        user = get_current_user()
        if not user or user.get('role') != 'admin':
            return jsonify({'error': 'Forbidden'}), 403
        return f(*args, **kwargs)
    return decorated_function


def get_settings():
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT key, value FROM app_settings')
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    settings = DEFAULT_SETTINGS.copy()
    for row in rows:
        settings[row['key']] = row['value']
    return settings


def save_settings(settings):
    conn = get_db()
    cursor = conn.cursor()
    for key, value in settings.items():
        cursor.execute('''
            INSERT INTO app_settings (key, value) VALUES (%s, %s)
            ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value
        ''', (key, str(value)))
    conn.commit()
    cursor.close()
    conn.close()
    return settings


def get_receipts_base_dir():
    settings = get_settings()
    path = settings.get('receipts_base_path', '') or str(DEFAULT_RECEIPTS_DIR)
    base = Path(path)
    base.mkdir(parents=True, exist_ok=True)
    return base


try:
    init_db()
except Exception as e:
    print(f'WARNING: Database initialization failed: {e}')
    print('The app will start but API calls requiring database access will fail until DATABASE_URL is configured.')


@app.route('/')
def index():
    return jsonify({'status': 'ok', 'service': 'AMD Parking Manager API'})


@app.route('/dashboard')
def dashboard():
    return redirect(APP_BASE_URL or '/')


@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.json or {}
    username = data.get('username', '').strip()
    password = data.get('password', '')
    ip = request.remote_addr
    if is_locked_out(username, ip):
        return jsonify({'error': 'Account temporarily locked. Try again later.'}), 429
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM users WHERE username = %s', (username,))
    user = cursor.fetchone()
    cursor.close()
    conn.close()
    if user and check_password_hash(user['password_hash'], password):
        if not user['active']:
            record_login_attempt(username, ip, False)
            return jsonify({'error': 'Account disabled'}), 403
        token = create_jwt_token(user)
        record_login_attempt(username, ip, True)
        log_audit('LOGIN', {'username': username})
        return jsonify({'success': True, 'token': token, 'name': user['name'], 'role': user['role']})
    record_login_attempt(username, ip, False)
    return jsonify({'error': 'Invalid username or password'}), 401


@app.route('/api/logout', methods=['POST'])
def api_logout():
    log_audit('LOGOUT', {})
    return jsonify({'success': True})


@app.route('/api/forgot-password', methods=['POST'])
def api_forgot_password():
    data = request.json or {}
    username = data.get('username', '').strip()
    if not username:
        return jsonify({'error': 'Username is required'}), 400
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM users WHERE username = %s', (username,))
    user = cursor.fetchone()
    if not user:
        cursor.close()
        conn.close()
        return jsonify({'error': 'Username not found'}), 404
    token = secrets.token_urlsafe(32)
    expiry = (datetime.now() + timedelta(hours=1)).isoformat()
    cursor.execute('''
        INSERT INTO password_reset_tokens (user_id, token, expiry)
        VALUES (%s, %s, %s)
    ''', (user['id'], token, expiry))
    conn.commit()
    cursor.close()
    conn.close()
    reset_link = f"{APP_BASE_URL}/reset-password.html?token={token}"
    send_reset_email(username, reset_link)
    log_audit('FORGOT_PASSWORD_REQUEST', {'username': username})
    return jsonify({'success': True, 'message': 'Reset link has been sent if the username exists'})


@app.route('/api/reset-password/<token>', methods=['POST'])
def api_reset_password(token):
    data = request.json or {}
    new_password = data.get('password', '')
    if len(new_password) < 6:
        return jsonify({'error': 'Password must be at least 6 characters'}), 400
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM password_reset_tokens WHERE token = %s AND used = 0', (token,))
    row = cursor.fetchone()
    if not row:
        cursor.close()
        conn.close()
        return jsonify({'error': 'Invalid or expired token'}), 400
    expiry = datetime.fromisoformat(row['expiry'])
    if datetime.now() > expiry:
        cursor.close()
        conn.close()
        return jsonify({'error': 'Token has expired'}), 400
    cursor.execute('UPDATE users SET password_hash = %s WHERE id = %s',
                   (generate_password_hash(new_password), row['user_id']))
    cursor.execute('UPDATE password_reset_tokens SET used = 1 WHERE id = %s', (row['id'],))
    conn.commit()
    cursor.execute('SELECT username FROM users WHERE id = %s', (row['user_id'],))
    username = cursor.fetchone()['username']
    cursor.close()
    conn.close()
    log_audit('PASSWORD_RESET', {'username': username})
    return jsonify({'success': True})


@app.route('/api/me', methods=['GET'])
@login_required
def api_me():
    user = get_current_user()
    return jsonify({
        'id': user.get('user_id'),
        'username': user.get('username'),
        'name': user.get('name'),
        'role': user.get('role')
    })


@app.route('/api/settings', methods=['GET'])
@login_required
def api_get_settings():
    return jsonify(get_settings())


@app.route('/api/settings', methods=['POST'])
@login_required
def api_save_settings():
    data = request.json or {}
    settings = get_settings()
    for key in DEFAULT_SETTINGS:
        if key in data:
            settings[key] = data[key]
    save_settings(settings)
    log_audit('UPDATE_SETTINGS', settings)
    return jsonify({'success': True, 'settings': settings})


@app.route('/api/stats', methods=['GET'])
@login_required
def api_stats():
    zone = request.args.get('zone', '')
    VT_PLANS = ['VT Transport Bulanan', 'VT Family Promo']
    DB_PLANS = ['DB Transport Bulanan', 'DB Family Promo']
    WARUNG_PLANS = ['Warung Bulanan']
    TRANSPORT_PLANS = VT_PLANS + DB_PLANS + WARUNG_PLANS
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    if zone == 'vista-tiara':
        placeholders = ','.join('%s' for _ in VT_PLANS)
        plan_filter = f'plan IN ({placeholders})'
        plan_params = VT_PLANS
    elif zone == 'danga-bay':
        placeholders = ','.join('%s' for _ in DB_PLANS)
        plan_filter = f'plan IN ({placeholders})'
        plan_params = DB_PLANS
    elif zone == 'warung':
        placeholders = ','.join('%s' for _ in WARUNG_PLANS)
        plan_filter = f'plan IN ({placeholders})'
        plan_params = WARUNG_PLANS
    else:
        placeholders = ','.join('%s' for _ in TRANSPORT_PLANS)
        plan_filter = f'plan NOT IN ({placeholders})'
        plan_params = TRANSPORT_PLANS

    cursor.execute(f'SELECT COUNT(*) as count FROM receipts WHERE {plan_filter}', plan_params)
    total = cursor.fetchone()['count']
    cursor.execute(f"SELECT COUNT(*) as count FROM receipts WHERE source = 'WhatsApp' AND {plan_filter}", plan_params)
    whatsapp = cursor.fetchone()['count']
    cursor.execute(f"SELECT COUNT(*) as count FROM receipts WHERE source = 'System' AND {plan_filter}", plan_params)
    invoice_count = cursor.fetchone()['count']
    today = datetime.now().strftime('%Y-%m-%d')
    cursor.execute(f'SELECT COUNT(*) as count FROM receipts WHERE DATE(created_at) = %s AND {plan_filter}', [today] + plan_params)
    today_count = cursor.fetchone()['count']
    cursor.execute(f"SELECT COALESCE(SUM(amount), 0) as revenue FROM receipts WHERE source = 'WhatsApp' AND {plan_filter}", plan_params)
    revenue = cursor.fetchone()['revenue']
    cursor.execute(f"SELECT COALESCE(SUM(amount), 0) as revenue FROM receipts WHERE source = 'System' AND {plan_filter}", plan_params)
    invoice_revenue = cursor.fetchone()['revenue']
    cursor.execute(f'''
        SELECT DATE(created_at) as date, COUNT(*) as count, COALESCE(SUM(amount), 0) as revenue
        FROM receipts WHERE created_at >= %s AND {plan_filter}
        GROUP BY DATE(created_at) ORDER BY DATE(created_at) DESC LIMIT 30
    ''', [datetime.now().strftime('%Y-%m-%d')] + plan_params)
    trend = [row_to_dict(r) for r in cursor.fetchall()]
    cursor.execute(f'''
        SELECT plan, COUNT(*) as count, COALESCE(SUM(amount), 0) as revenue
        FROM receipts WHERE {plan_filter}
        GROUP BY plan ORDER BY count DESC
    ''', plan_params)
    plan_summary = [row_to_dict(r) for r in cursor.fetchall()]
    if zone in ('vista-tiara', 'danga-bay', 'warung'):
        monthly = 0
        daily = 0
    else:
        monthly = sum(1 for p in plan_summary if p['plan'] in MONTHLY_PLANS)
        daily = sum(1 for p in plan_summary if p['plan'] in DAILY_PLANS)
    cursor.close()
    conn.close()
    return jsonify({
        'total': total,
        'whatsapp': whatsapp,
        'invoice_count': invoice_count,
        'today': today_count,
        'revenue': revenue,
        'invoice_revenue': invoice_revenue,
        'monthly': monthly,
        'daily': daily,
        'trend': trend,
        'plan_summary': plan_summary
    })


@app.route('/api/customer-stats', methods=['GET'])
@login_required
def api_customer_stats():
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute(f"SELECT COUNT(*) as count FROM customers WHERE status = 'Active' AND plan IN ({','.join('%s' for _ in MONTHLY_PLANS)})", MONTHLY_PLANS)
    active_monthly = cursor.fetchone()['count']
    cursor.execute(f"SELECT COUNT(*) as count FROM customers WHERE status = 'Active' AND plan IN ({','.join('%s' for _ in DAILY_PLANS)})", DAILY_PLANS)
    active_daily = cursor.fetchone()['count']
    cursor.execute("SELECT COUNT(*) as count FROM customers WHERE status = 'Terminated'")
    terminated = cursor.fetchone()['count']
    cursor.execute('SELECT COUNT(*) as count FROM customers')
    total = cursor.fetchone()['count']
    cursor.close()
    conn.close()
    return jsonify({'active_monthly': active_monthly, 'active_daily': active_daily, 'terminated': terminated, 'total': total})


@app.route('/api/receipts', methods=['GET'])
@login_required
def api_get_receipts():
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    query = 'SELECT * FROM receipts WHERE 1=1'
    params = []
    search = request.args.get('search', '')
    if search:
        query += ''' AND (
            customer_name LIKE %s OR
            vehicle_number LIKE %s OR
            phone LIKE %s OR
            receipt_number LIKE %s
        )'''
        like = f'%%{search}%%'
        params.extend([like, like, like, like])
    status = request.args.get('status', '')
    if status:
        query += ' AND status = %s'
        params.append(status)
    source = request.args.get('source', '')
    if source:
        query += ' AND source = %s'
        params.append(source)
    plan = request.args.get('plan', '')
    if plan:
        query += ' AND plan = %s'
        params.append(plan)
    zone = request.args.get('zone', '')
    if zone:
        if zone == 'vista-tiara':
            query += " AND plan IN ('VT Transport Bulanan', 'VT Family Promo')"
        elif zone == 'danga-bay':
            query += " AND plan IN ('DB Transport Bulanan', 'DB Family Promo')"
        elif zone == 'warung':
            query += " AND plan IN ('Warung Bulanan')"
        elif zone == 'parking':
            query += " AND plan NOT IN ('VT Transport Bulanan', 'VT Family Promo', 'DB Transport Bulanan', 'DB Family Promo', 'Warung Bulanan')"
    date_from = request.args.get('dateFrom', '')
    if date_from:
        query += ' AND created_at >= %s'
        params.append(date_from)
    date_to = request.args.get('dateTo', '')
    if date_to:
        query += ' AND created_at <= %s'
        params.append(f'{date_to}T23:59:59')
    query += ' ORDER BY created_at DESC'
    cursor.execute(query, params)
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify([row_to_dict(row) for row in rows])


@app.route('/api/receipts', methods=['POST'])
@login_required
def api_create_receipt():
    data = request.json or {}
    rate = float(data.get('ratePerHour', 0))
    duration = int(data.get('durationMinutes', 0) or 0)
    amount = float(data.get('amount', 0)) if data.get('amount') is not None else max(0, (duration / 60) * rate)
    receipt_number = f"RCP-{datetime.now().strftime('%Y%m%d%H%M%S')}-{os.urandom(2).hex().upper()}"
    user = get_current_user()
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('''
        INSERT INTO receipts (
            receipt_number, customer_name, phone, vehicle_number, slot_code,
            entry_time, exit_time, duration_minutes, rate_per_hour, amount,
            payment_method, plan, status, notes, source, created_by
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    ''', (
        receipt_number,
        data.get('customerName', ''),
        data.get('phone', ''),
        data.get('vehicleNumber', ''),
        data.get('slotCode', ''),
        data.get('entryTime') or None,
        data.get('exitTime') or None,
        duration,
        rate,
        amount,
        data.get('paymentMethod', 'Cash'),
        data.get('plan', 'Harian Parking'),
        data.get('status', 'Pending'),
        data.get('notes', ''),
        'System',
        user.get('user_id') if user else None
    ))
    receipt_id = cursor.fetchone()['id']
    conn.commit()
    cursor.execute('SELECT * FROM receipts WHERE id = %s', (receipt_id,))
    row = cursor.fetchone()
    receipt_dict = row_to_dict(row)
    sync_customer_from_receipt(receipt_dict)
    cursor.close()
    conn.close()
    log_audit('CREATE_RECEIPT', {'receipt_id': receipt_id, 'receipt_number': receipt_number})
    return jsonify({'success': True, 'receipt': receipt_dict})


@app.route('/api/receipts/<int:receipt_id>', methods=['GET'])
@login_required
def api_get_receipt(receipt_id):
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM receipts WHERE id = %s', (receipt_id,))
    row = cursor.fetchone()
    cursor.close()
    conn.close()
    if row:
        return jsonify(row_to_dict(row))
    return jsonify({'error': 'Receipt not found'}), 404


@app.route('/api/receipts/<int:receipt_id>', methods=['PUT'])
@login_required
def api_update_receipt(receipt_id):
    data = request.json or {}
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM receipts WHERE id = %s', (receipt_id,))
    existing = cursor.fetchone()
    if not existing:
        cursor.close()
        conn.close()
        return jsonify({'error': 'Receipt not found'}), 404
    updates = []
    params = []
    key_map = {
        'customer_name': 'customerName',
        'phone': 'phone',
        'vehicle_number': 'vehicleNumber',
        'slot_code': 'slotCode',
        'entry_time': 'entryTime',
        'exit_time': 'exitTime',
        'duration_minutes': 'durationMinutes',
        'rate_per_hour': 'ratePerHour',
        'amount': 'amount',
        'payment_method': 'paymentMethod',
        'plan': 'plan',
        'status': 'status',
        'notes': 'notes'
    }
    for col, key in key_map.items():
        if key in data:
            updates.append(f'{col} = %s')
            params.append(data[key])
    if not updates:
        cursor.close()
        conn.close()
        return jsonify({'error': 'No updates provided'}), 400
    params.append(receipt_id)
    cursor.execute(f"UPDATE receipts SET {', '.join(updates)}, updated_at = CURRENT_TIMESTAMP WHERE id = %s", params)
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('UPDATE_RECEIPT', {'receipt_id': receipt_id})
    return jsonify({'success': True})


@app.route('/api/receipts/<int:receipt_id>', methods=['DELETE'])
@login_required
def api_delete_receipt(receipt_id):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('DELETE FROM receipts WHERE id = %s', (receipt_id,))
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('DELETE_RECEIPT', {'receipt_id': receipt_id})
    return jsonify({'success': True})


@app.route('/api/receipts/<int:receipt_id>/save-png', methods=['POST'])
@login_required
def api_save_receipt_png(receipt_id):
    data = request.json or {}
    image_data = data.get('imageData', '')
    if not image_data:
        return jsonify({'error': 'No image data'}), 400
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('UPDATE receipts SET file_data = %s, file_path = %s WHERE id = %s',
                   (image_data, f'receipt_{receipt_id}.png', receipt_id))
    conn.commit()
    cursor.close()
    conn.close()
    return jsonify({'success': True, 'folder': 'database'})


@app.route('/api/whatsapp-receipts', methods=['POST'])
@login_required
def api_store_whatsapp_receipt():
    data = request.json or {}
    file_data = data.get('fileData', '')
    file_name = data.get('fileName', 'receipt.bin')
    if not file_data:
        return jsonify({'error': 'No file data provided'}), 400
    try:
        header, encoded = file_data.split(',', 1)
        file_bytes = base64.b64decode(encoded)
    except Exception:
        return jsonify({'error': 'Invalid file data'}), 400
    stored_data = file_data
    receipt_number = f"RCP-WA-{datetime.now().strftime('%Y%m%d%H%M%S')}-{os.urandom(2).hex().upper()}"
    user = get_current_user()
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('''
        INSERT INTO receipts (
            receipt_number, customer_name, phone, vehicle_number, slot_code,
            amount, payment_method, plan, status, notes, file_path, file_data, source, created_by
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    ''', (
        receipt_number,
        data.get('customerName', 'WhatsApp Customer'),
        data.get('phone', ''),
        data.get('vehicleNumber', ''),
        data.get('slotCode', ''),
        float(data.get('amount', 0) or 0),
        data.get('paymentMethod', 'WhatsApp'),
        data.get('plan', 'Harian Parking'),
        'WhatsApp Received',
        data.get('notes', ''),
        file_name,
        stored_data,
        'WhatsApp',
        user.get('user_id') if user else None
    ))
    receipt_id = cursor.fetchone()['id']
    conn.commit()
    cursor.execute('SELECT * FROM receipts WHERE id = %s', (receipt_id,))
    row = cursor.fetchone()
    receipt_dict = row_to_dict(row)
    if 'file_data' in receipt_dict:
        del receipt_dict['file_data']
    sync_customer_from_receipt(receipt_dict)
    cursor.close()
    conn.close()
    log_audit('STORE_WHATSAPP_RECEIPT', {'receipt_id': receipt_id, 'receipt_number': receipt_number})
    return jsonify({'success': True, 'receipt': receipt_dict})


@app.route('/api/files/<path:filename>', methods=['GET'])
def api_get_file(filename):
    token = request.args.get('token', '')
    if token:
        payload = decode_jwt_token(token)
        if not payload:
            return jsonify({'error': 'Unauthorized'}), 401
    else:
        user = get_current_user()
        if not user:
            return jsonify({'error': 'Unauthorized'}), 401
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT file_data FROM receipts WHERE file_path = %s', (filename,))
    row = cursor.fetchone()
    cursor.close()
    conn.close()
    if not row or not row['file_data']:
        return jsonify({'error': 'File not found'}), 404
    try:
        header, encoded = row['file_data'].split(',', 1)
        file_bytes = base64.b64decode(encoded)
    except Exception:
        return jsonify({'error': 'Invalid file data'}), 400
    return send_file(io.BytesIO(file_bytes), mimetype='application/octet-stream', as_attachment=True, download_name=filename)


@app.route('/api/transport-customers', methods=['GET'])
@login_required
def api_get_transport_customers():
    zone = request.args.get('zone', '')
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    if zone:
        cursor.execute('SELECT * FROM transport_customers WHERE zone = %s ORDER BY created_at DESC', (zone,))
    else:
        cursor.execute('SELECT * FROM transport_customers ORDER BY created_at DESC')
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify([row_to_dict(row) for row in rows])


@app.route('/api/transport-customers', methods=['POST'])
@login_required
def api_create_transport_customer():
    data = request.json or {}
    if not data.get('customer_name') or not data.get('zone') or not data.get('package'):
        return jsonify({'error': 'Nama, zon, dan pakej diperlukan'}), 400
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO transport_customers (zone, customer_name, phone, package, pax, amount, status, start_date, end_date, notes)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id
    ''', (
        data['zone'],
        data['customer_name'],
        data.get('phone', ''),
        data['package'],
        int(data.get('pax', 1)),
        float(data.get('amount', 0)),
        data.get('status', 'Active'),
        data.get('start_date', ''),
        data.get('end_date', ''),
        data.get('notes', '')
    ))
    customer_id = cursor.fetchone()['id']
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('CREATE_TRANSPORT_CUSTOMER', {'id': customer_id, 'zone': data['zone'], 'name': data['customer_name']})
    return jsonify({'success': True, 'id': customer_id})


@app.route('/api/transport-customers/<int:customer_id>', methods=['PUT'])
@login_required
def api_update_transport_customer(customer_id):
    data = request.json or {}
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM transport_customers WHERE id = %s', (customer_id,))
    existing = cursor.fetchone()
    if not existing:
        cursor.close()
        conn.close()
        return jsonify({'error': 'Pelanggan tidak dijumpai'}), 404
    cursor.execute('''
        UPDATE transport_customers SET
            customer_name = %s, phone = %s, package = %s, pax = %s, amount = %s,
            status = %s, start_date = %s, end_date = %s, notes = %s, updated_at = CURRENT_TIMESTAMP
        WHERE id = %s
    ''', (
        data.get('customer_name', existing['customer_name']),
        data.get('phone', existing['phone']),
        data.get('package', existing['package']),
        int(data.get('pax', existing['pax'])),
        float(data.get('amount', existing['amount'])),
        data.get('status', existing['status']),
        data.get('start_date', existing['start_date']),
        data.get('end_date', existing['end_date']),
        data.get('notes', existing['notes']),
        customer_id
    ))
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('UPDATE_TRANSPORT_CUSTOMER', {'id': customer_id})
    return jsonify({'success': True})


@app.route('/api/transport-customers/<int:customer_id>', methods=['DELETE'])
@login_required
def api_delete_transport_customer(customer_id):
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM transport_customers WHERE id = %s', (customer_id,))
    existing = cursor.fetchone()
    if not existing:
        cursor.close()
        conn.close()
        return jsonify({'error': 'Pelanggan tidak dijumpai'}), 404
    cursor.execute('DELETE FROM transport_customers WHERE id = %s', (customer_id,))
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('DELETE_TRANSPORT_CUSTOMER', {'id': customer_id, 'name': existing['customer_name']})
    return jsonify({'success': True})


@app.route('/api/transport-stats', methods=['GET'])
@login_required
def api_transport_stats():
    zone = request.args.get('zone', '')
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    if zone:
        cursor.execute('SELECT * FROM transport_customers WHERE zone = %s', (zone,))
    else:
        cursor.execute('SELECT * FROM transport_customers')
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    active = [r for r in rows if r['status'] == 'Active']
    terminated = [r for r in rows if r['status'] == 'Terminated']
    total_pax = sum(r['pax'] for r in active)
    total_revenue = sum(r['amount'] for r in active)
    return jsonify({
        'active': len(active),
        'terminated': len(terminated),
        'total_pax': total_pax,
        'total_revenue': round(total_revenue, 2)
    })


@app.route('/api/users', methods=['GET'])
@admin_required
def api_get_users():
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT id, username, role, name, active, created_at FROM users ORDER BY created_at DESC')
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify([row_to_dict(row) for row in rows])


@app.route('/api/users', methods=['POST'])
@admin_required
def api_create_user():
    data = request.json or {}
    if not data.get('username') or not data.get('password'):
        return jsonify({'error': 'Username and password required'}), 400
    if len(data['password']) < 6:
        return jsonify({'error': 'Password must be at least 6 characters'}), 400
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute('''
            INSERT INTO users (username, password_hash, role, name)
            VALUES (%s, %s, %s, %s)
            RETURNING id
        ''', (data['username'], generate_password_hash(data['password']), data.get('role', 'manager'), data.get('name', '')))
        user_id = cursor.fetchone()['id']
        conn.commit()
    except psycopg2.errors.UniqueViolation:
        conn.rollback()
        cursor.close()
        conn.close()
        return jsonify({'error': 'Username already exists'}), 400
    cursor.close()
    conn.close()
    log_audit('CREATE_USER', {'user_id': user_id, 'username': data['username']})
    return jsonify({'success': True, 'user_id': user_id})


@app.route('/api/users/<int:user_id>', methods=['PUT'])
@admin_required
def api_update_user(user_id):
    data = request.json or {}
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM users WHERE id = %s', (user_id,))
    existing = cursor.fetchone()
    if not existing:
        cursor.close()
        conn.close()
        return jsonify({'error': 'User not found'}), 404
    updates = []
    params = []
    if 'role' in data:
        updates.append('role = %s')
        params.append(data['role'])
    if 'name' in data:
        updates.append('name = %s')
        params.append(data['name'])
    if 'active' in data:
        updates.append('active = %s')
        params.append(1 if data['active'] else 0)
    if 'password' in data and data['password']:
        if len(data['password']) < 6:
            cursor.close()
            conn.close()
            return jsonify({'error': 'Password must be at least 6 characters'}), 400
        updates.append('password_hash = %s')
        params.append(generate_password_hash(data['password']))
    if not updates:
        cursor.close()
        conn.close()
        return jsonify({'error': 'No updates provided'}), 400
    params.append(user_id)
    cursor.execute(f"UPDATE users SET {', '.join(updates)} WHERE id = %s", params)
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('UPDATE_USER', {'user_id': user_id})
    return jsonify({'success': True})


@app.route('/api/users/<int:user_id>', methods=['DELETE'])
@admin_required
def api_delete_user(user_id):
    user = get_current_user()
    if user and user.get('user_id') == user_id:
        return jsonify({'error': 'Cannot delete yourself'}), 400
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('DELETE FROM users WHERE id = %s', (user_id,))
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('DELETE_USER', {'user_id': user_id})
    return jsonify({'success': True})


@app.route('/api/audit-logs', methods=['GET'])
@admin_required
def api_audit_logs():
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    limit = request.args.get('limit', 100, type=int)
    cursor.execute('''
        SELECT * FROM audit_logs
        ORDER BY created_at DESC
        LIMIT %s
    ''', (limit,))
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify([row_to_dict(row) for row in rows])


@app.route('/api/export/csv', methods=['GET'])
@login_required
def api_export_csv():
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM receipts ORDER BY created_at DESC')
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['ID', 'Invoice Number', 'Customer', 'Phone', 'Vehicle', 'Slot', 'Plan', 'Status',
                     'Amount', 'Payment Method', 'Entry Time', 'Exit Time', 'Duration', 'Source', 'Created At'])
    for row in rows:
        writer.writerow([
            row['id'], row['receipt_number'], row['customer_name'], row['phone'], row['vehicle_number'],
            row['slot_code'], row['plan'], row['status'], row['amount'], row['payment_method'],
            row['entry_time'], row['exit_time'], row['duration_minutes'], row['source'], row['created_at']
        ])
    output.seek(0)
    return send_file(
        io.BytesIO(output.getvalue().encode('utf-8-sig')),
        mimetype='text/csv',
        as_attachment=True,
        download_name=f'invoices_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'
    )


@app.route('/api/customers', methods=['GET'])
@login_required
def api_get_customers():
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    query = 'SELECT * FROM customers WHERE 1=1'
    params = []
    plan_type = request.args.get('planType', '')
    if plan_type == 'monthly':
        query += f" AND plan IN ({','.join('%s' for _ in MONTHLY_PLANS)})"
        params.extend(MONTHLY_PLANS)
    elif plan_type == 'daily':
        query += f" AND plan IN ({','.join('%s' for _ in DAILY_PLANS)})"
        params.extend(DAILY_PLANS)
    status = request.args.get('status', '')
    if status:
        query += ' AND status = %s'
        params.append(status)
    query += ' ORDER BY created_at DESC'
    cursor.execute(query, params)
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify([row_to_dict(row) for row in rows])


@app.route('/api/customers/<int:customer_id>', methods=['GET'])
@login_required
def api_get_customer(customer_id):
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM customers WHERE id = %s', (customer_id,))
    row = cursor.fetchone()
    cursor.close()
    conn.close()
    if row:
        return jsonify(row_to_dict(row))
    return jsonify({'error': 'Customer not found'}), 404


@app.route('/api/customers', methods=['POST'])
@login_required
def api_create_customer():
    data = request.json or {}
    if not data.get('customerName') or not data.get('vehicleNumber'):
        return jsonify({'error': 'Customer name and vehicle number required'}), 400
    conn = get_db()
    cursor = conn.cursor()
    today = datetime.now().strftime('%Y-%m-%d')
    plan = data.get('plan', 'Harian Parking')
    is_monthly = plan in MONTHLY_PLANS
    start_date = data.get('startDate') or today
    end_date = data.get('endDate')
    if is_monthly and not end_date:
        end_date = (datetime.strptime(start_date, '%Y-%m-%d') + timedelta(days=30)).strftime('%Y-%m-%d')
    try:
        cursor.execute('''
            INSERT INTO customers (
                customer_name, phone, vehicle_number, plan, status, start_date, end_date,
                monthly_rate, transport_included, notes
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        ''', (
            data['customerName'],
            data.get('phone', ''),
            data['vehicleNumber'],
            plan,
            data.get('status', 'Active'),
            start_date,
            end_date,
            float(data.get('monthlyRate', 0)),
            1 if data.get('transportIncluded') else 0,
            data.get('notes', '')
        ))
        customer_id = cursor.fetchone()['id']
        conn.commit()
    except psycopg2.errors.UniqueViolation:
        conn.rollback()
        cursor.close()
        conn.close()
        return jsonify({'error': 'Vehicle number already exists'}), 400
    cursor.close()
    conn.close()
    log_audit('CREATE_CUSTOMER', {'customer_id': customer_id, 'vehicle_number': data['vehicleNumber']})
    return jsonify({'success': True, 'customer_id': customer_id})


@app.route('/api/customers/<int:customer_id>', methods=['PUT'])
@login_required
def api_update_customer(customer_id):
    data = request.json or {}
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM customers WHERE id = %s', (customer_id,))
    existing = cursor.fetchone()
    if not existing:
        cursor.close()
        conn.close()
        return jsonify({'error': 'Customer not found'}), 404
    updates = []
    params = []
    fields = {
        'customer_name': 'customerName',
        'phone': 'phone',
        'vehicle_number': 'vehicleNumber',
        'plan': 'plan',
        'status': 'status',
        'start_date': 'startDate',
        'end_date': 'endDate',
        'monthly_rate': 'monthlyRate',
        'transport_included': 'transportIncluded',
        'notes': 'notes'
    }
    for col, key in fields.items():
        if key in data:
            val = data[key]
            if key == 'transportIncluded':
                val = 1 if val else 0
            elif key == 'monthlyRate':
                val = float(val or 0)
            updates.append(f'{col} = %s')
            params.append(val)
    if not updates:
        cursor.close()
        conn.close()
        return jsonify({'error': 'No updates provided'}), 400
    params.append(customer_id)
    cursor.execute(f"UPDATE customers SET {', '.join(updates)}, updated_at = CURRENT_TIMESTAMP WHERE id = %s", params)
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('UPDATE_CUSTOMER', {'customer_id': customer_id})
    return jsonify({'success': True})


@app.route('/api/customers/<int:customer_id>/terminate', methods=['POST'])
@login_required
def api_terminate_customer(customer_id):
    data = request.json or {}
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM customers WHERE id = %s', (customer_id,))
    existing = cursor.fetchone()
    if not existing:
        cursor.close()
        conn.close()
        return jsonify({'error': 'Customer not found'}), 404
    end_date = data.get('endDate') or datetime.now().strftime('%Y-%m-%d')
    notes = data.get('notes', existing['notes'])
    cursor.execute('''
        UPDATE customers SET status = 'Terminated', end_date = %s, notes = %s, updated_at = CURRENT_TIMESTAMP
        WHERE id = %s
    ''', (end_date, notes, customer_id))
    user = get_current_user()
    cursor.execute('''
        INSERT INTO history_records (
            customer_id, customer_name, vehicle_number, phone, plan, monthly_rate,
            start_date, end_date, notes, terminated_by, terminated_by_name
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    ''', (
        existing['id'],
        existing['customer_name'],
        existing['vehicle_number'],
        existing['phone'],
        existing['plan'],
        existing['monthly_rate'],
        existing['start_date'],
        end_date,
        notes,
        user.get('user_id') if user else None,
        user.get('username') if user else None
    ))
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('TERMINATE_CUSTOMER', {'customer_id': customer_id, 'vehicle_number': existing['vehicle_number']})
    return jsonify({'success': True})


@app.route('/api/customers/<int:customer_id>', methods=['DELETE'])
@login_required
def api_delete_customer(customer_id):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('DELETE FROM customers WHERE id = %s', (customer_id,))
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('DELETE_CUSTOMER', {'customer_id': customer_id})
    return jsonify({'success': True})


@app.route('/api/customers/terminated', methods=['DELETE'])
@admin_required
def api_clear_terminated_customers():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM customers WHERE status = %s", ('Terminated',))
    deleted = cursor.rowcount
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('CLEAR_TERMINATED_CUSTOMERS', {'deleted': deleted})
    return jsonify({'success': True, 'deleted': deleted})


@app.route('/api/history', methods=['GET'])
@login_required
def api_get_history():
    conn = get_db()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute('SELECT * FROM history_records ORDER BY terminated_at DESC')
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify([row_to_dict(row) for row in rows])


@app.route('/api/history', methods=['DELETE'])
@admin_required
def api_clear_history():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('DELETE FROM history_records')
    conn.commit()
    cursor.close()
    conn.close()
    log_audit('CLEAR_HISTORY', {})
    return jsonify({'success': True})


@app.route('/api/backup', methods=['POST'])
@admin_required
def api_backup():
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_name = f'backup_{timestamp}.zip'
    backup_path = BACKUP_DIR / backup_name
    with zipfile.ZipFile(backup_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        settings = get_settings()
        zf.writestr('settings.json', json.dumps(settings, default=str))
        conn = get_db()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT * FROM receipts')
        receipts = cursor.fetchall()
        cursor.execute('SELECT * FROM customers')
        customers = cursor.fetchall()
        cursor.execute('SELECT * FROM transport_customers')
        transport = cursor.fetchall()
        cursor.execute('SELECT * FROM users')
        users = cursor.fetchall()
        cursor.close()
        conn.close()
        zf.writestr('receipts.json', json.dumps([row_to_dict(r) for r in receipts], default=str))
        zf.writestr('customers.json', json.dumps([row_to_dict(r) for r in customers], default=str))
        zf.writestr('transport_customers.json', json.dumps([row_to_dict(r) for r in transport], default=str))
        zf.writestr('users.json', json.dumps([{k: v for k, v in row_to_dict(u).items() if k != 'password_hash'} for u in users], default=str))
    log_audit('BACKUP', {'backup_name': backup_name})
    return jsonify({'success': True, 'backup_name': backup_name})


@app.route('/api/backups', methods=['GET'])
@admin_required
def api_get_backups():
    backups = []
    for path in sorted(BACKUP_DIR.glob('*.zip'), reverse=True):
        backups.append({
            'name': path.name,
            'size': path.stat().st_size,
            'created': datetime.fromtimestamp(path.stat().st_mtime).isoformat()
        })
    return jsonify(backups)


@app.route('/api/backups/<path:filename>', methods=['GET'])
@admin_required
def api_download_backup(filename):
    file_path = BACKUP_DIR / filename
    if not file_path.exists():
        return jsonify({'error': 'Backup not found'}), 404
    return send_from_directory(BACKUP_DIR, filename, as_attachment=True)


@app.route('/api/backups/<path:filename>', methods=['DELETE'])
@admin_required
def api_delete_backup(filename):
    file_path = BACKUP_DIR / filename
    if file_path.exists():
        file_path.unlink()
    log_audit('DELETE_BACKUP', {'filename': filename})
    return jsonify({'success': True})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=PORT, debug=False)

