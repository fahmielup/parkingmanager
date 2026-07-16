"""
ToyyibPay subscription billing blueprint for the Parking Shuttle SaaS.

SECURITY MODEL:
- The mobile Flutter client NEVER holds ToyyibPay secrets. It only POSTs
  a payload to /api/toyyibpay/create-bill on this trusted PC backend.
- This server creates the bill with ToyyibPay using TOYYIBPAY_SECRET_KEY
  and returns the generated `billUrl` for the client to open externally.
- ToyyibPay calls /api/toyyibpay/webhook after payment. On a successful
  transaction this server (and ONLY this server):
    1. Flips `registered_hubs/{hubId}.status` to 'active' and extends the
       subscription window by 30 days.
    2. Logs the transaction into the `financial_transactions` Firestore
       collection for legal billing auditing.

CONFIGURATION (environment variables, or a `.env` file beside this module):
    TOYYIBPAY_SECRET_KEY      ToyyibPay API secret key (required for live use)
    TOYYIBPAY_CATEGORY_CODE   ToyyibPay category code (required for live use)
                              (legacy alias TOYYIBPAY_CATEGORY also accepted)
    TOYYIBPAY_BASE_URL        Defaults to https://toyyibpay.com
                              (use https://dev.toyyibpay.com for sandbox)
    TOYYIBPAY_CALLBACK_BASE   PUBLIC base URL reachable by ToyyibPay servers
                              (e.g. your ngrok https URL). Falls back to the
                              request host, which only works when public.
    FIREBASE_PROJECT_ID       Defaults to parkingmanager-a18e6
"""

import logging
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests as http_requests
from flask import Blueprint, jsonify, request

logger = logging.getLogger('toyyibpay')

toyyibpay_bp = Blueprint('toyyibpay', __name__)


# ---------------------------------------------------------------------------
# Configuration loading (.env file overrides nothing; env vars win)
# ---------------------------------------------------------------------------

def _load_dotenv() -> dict:
    """Minimal .env parser (no external dependency)."""
    env_file = Path(__file__).parent / '.env'
    values = {}
    if env_file.exists():
        for line in env_file.read_text(encoding='utf-8').splitlines():
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, _, value = line.partition('=')
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values


_DOTENV = _load_dotenv()


def _config(*names: str, default: str = '') -> str:
    """Resolve config: process env first, then .env file, then default.
    Placeholder values (e.g. 'your_..._here') are treated as unset."""
    for name in names:
        value = os.environ.get(name) or _DOTENV.get(name)
        if value and not value.startswith('your_'):
            return value
    return default


TOYYIBPAY_BASE_URL = _config('TOYYIBPAY_BASE_URL', default='https://toyyibpay.com')
TOYYIBPAY_SECRET_KEY = _config('TOYYIBPAY_SECRET_KEY')
TOYYIBPAY_CATEGORY = _config('TOYYIBPAY_CATEGORY_CODE', 'TOYYIBPAY_CATEGORY')
TOYYIBPAY_CALLBACK_BASE = _config('TOYYIBPAY_CALLBACK_BASE')
FIREBASE_PROJECT_ID = _config('FIREBASE_PROJECT_ID', default='parkingmanager-a18e6')

FIRESTORE_BASE = (
    f'https://firestore.googleapis.com/v1/projects/{FIREBASE_PROJECT_ID}'
    f'/databases/(default)/documents'
)


# ---------------------------------------------------------------------------
# Firebase Admin SDK (production-grade) with REST fallback (development)
#
# Place `serviceAccountKey.json` beside this module to enable the Admin SDK:
#   Firebase Console > Project Settings > Service Accounts >
#   Generate New Private Key
# The Admin SDK bypasses security rules safely server-side, so Firestore
# rules can be locked down for mobile clients without breaking billing.
# ---------------------------------------------------------------------------

_admin_db = None
_SERVICE_ACCOUNT_FILE = Path(__file__).parent / 'serviceAccountKey.json'

if _SERVICE_ACCOUNT_FILE.exists():
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore as admin_firestore

        if not firebase_admin._apps:
            cred = credentials.Certificate(str(_SERVICE_ACCOUNT_FILE))
            firebase_admin.initialize_app(cred)
        _admin_db = admin_firestore.client()
        logger.info('Firebase Admin SDK active (service account).')
    except ImportError:
        logger.warning(
            'serviceAccountKey.json found but firebase-admin not installed. '
            'Run: pip install firebase-admin. Falling back to REST.')
    except Exception as exc:  # invalid key file, etc.
        logger.error('Firebase Admin SDK init failed: %s. Using REST.', exc)
else:
    logger.info('No serviceAccountKey.json - using Firestore REST fallback.')


# ---------------------------------------------------------------------------
# Firestore REST helpers (server-side writes only)
# ---------------------------------------------------------------------------

def _ts(dt: datetime) -> dict:
    return {'timestampValue': dt.strftime('%Y-%m-%dT%H:%M:%SZ')}


def _activate_hub(hub_id: str) -> bool:
    """Flip the tenant hub to 'active' and extend the licence by 30 days."""
    now = datetime.now(timezone.utc)

    # Preferred path: Firebase Admin SDK (secure, rules-independent).
    if _admin_db is not None:
        try:
            hub_ref = _admin_db.collection('registered_hubs').document(hub_id)
            if not hub_ref.get().exists:
                logger.error('Hub %s not found in registered_hubs.', hub_id)
                return False
            hub_ref.update({
                'status': 'active',
                'trialStartDate': now,
                'trialEndDate': now + timedelta(days=30),
                'updatedAt': now,
            })
            logger.info('[ADMIN SDK] Hub %s reactivated until %s.',
                        hub_id, (now + timedelta(days=30)).date())
            return True
        except Exception as exc:
            logger.error('[ADMIN SDK] Hub activation failed: %s', exc)
            return False

    # Fallback path: Firestore REST (development, open rules only).
    body = {
        'fields': {
            'status': {'stringValue': 'active'},
            'trialStartDate': _ts(now),
            'trialEndDate': _ts(now + timedelta(days=30)),
        }
    }
    url = (
        f'{FIRESTORE_BASE}/registered_hubs/{hub_id}'
        '?updateMask.fieldPaths=status'
        '&updateMask.fieldPaths=trialStartDate'
        '&updateMask.fieldPaths=trialEndDate'
    )
    try:
        resp = http_requests.patch(url, json=body, timeout=15)
        ok = resp.status_code == 200
        if not ok:
            logger.error('Hub activation failed (%s): %s',
                         resp.status_code, resp.text[:200])
        else:
            logger.info('Hub %s activated until %s', hub_id,
                        (now + timedelta(days=30)).date())
        return ok
    except http_requests.RequestException as exc:
        logger.error('Hub activation network error: %s', exc)
        return False


def _log_transaction(payload: dict) -> None:
    """Append an immutable audit record into `financial_transactions`."""
    # Preferred path: Firebase Admin SDK.
    if _admin_db is not None:
        try:
            record = dict(payload)
            record['loggedAt'] = datetime.now(timezone.utc)
            _admin_db.collection('financial_transactions').add(record)
            return
        except Exception as exc:
            logger.error('[ADMIN SDK] Transaction log failed: %s', exc)
            return

    # Fallback path: Firestore REST.
    fields = {}
    for key, value in payload.items():
        if isinstance(value, bool):
            fields[key] = {'booleanValue': value}
        elif isinstance(value, int):
            fields[key] = {'integerValue': str(value)}
        elif isinstance(value, float):
            fields[key] = {'doubleValue': value}
        else:
            fields[key] = {'stringValue': str(value)}
    fields['loggedAt'] = _ts(datetime.now(timezone.utc))
    try:
        http_requests.post(
            f'{FIRESTORE_BASE}/financial_transactions',
            json={'fields': fields},
            timeout=15,
        )
    except http_requests.RequestException as exc:
        logger.error('Transaction audit log failed: %s', exc)


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@toyyibpay_bp.route('/api/toyyibpay/config-check', methods=['GET'])
def config_check():
    """Diagnostics: verify config is loaded WITHOUT exposing secrets."""
    return jsonify({
        'secretKeyLoaded': bool(TOYYIBPAY_SECRET_KEY),
        'categoryCodeLoaded': bool(TOYYIBPAY_CATEGORY),
        'baseUrl': TOYYIBPAY_BASE_URL,
        'callbackBase': TOYYIBPAY_CALLBACK_BASE or '(auto: request host)',
        'mode': 'LIVE' if TOYYIBPAY_SECRET_KEY and TOYYIBPAY_CATEGORY
                else 'SANDBOX (missing keys)',
    })


@toyyibpay_bp.route('/api/toyyibpay/create-bill', methods=['POST'])
def create_bill():
    """Secure handshake: mobile client -> this server -> ToyyibPay."""
    data = request.get_json(silent=True) or {}
    required = ['hubId', 'tenantAdminId', 'billName', 'billDescription',
                'billPrice', 'billEmail', 'billPhone']
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({'error': f'Missing fields: {", ".join(missing)}'}), 400

    # Validate the amount (integer cents, RM 1.00 minimum, RM 10,000 cap).
    try:
        amount_cents = int(data['billPrice'])
    except (TypeError, ValueError):
        return jsonify({'error': 'billPrice must be an integer (cents)'}), 400
    if not 100 <= amount_cents <= 1_000_000:
        return jsonify({'error': 'billPrice out of allowed range'}), 400

    # Development fallback: without live keys, return a sandbox-style URL so
    # the mobile payment flow can be tested end-to-end.
    if not TOYYIBPAY_SECRET_KEY or not TOYYIBPAY_CATEGORY:
        logger.warning('ToyyibPay keys missing - responding in SANDBOX mode')
        return jsonify({
            'billUrl': f'{TOYYIBPAY_BASE_URL}/umobile-dev-sandbox',
            'billCode': 'DEV-SANDBOX',
            'sandbox': True,
        })

    # Public base for callbacks: explicit config wins; else request host.
    callback_base = (TOYYIBPAY_CALLBACK_BASE or request.host_url).rstrip('/')

    try:
        resp = http_requests.post(
            f'{TOYYIBPAY_BASE_URL}/index.php/api/createBill',
            data={
                'userSecretKey': TOYYIBPAY_SECRET_KEY,
                'categoryCode': TOYYIBPAY_CATEGORY,
                'billName': data['billName'][:30],
                'billDescription': data['billDescription'][:100],
                'billPriceSetting': 1,
                'billPayorInfo': 1,
                'billAmount': amount_cents,  # cents (e.g. 25000 = RM250)
                'billReturnUrl': f'{callback_base}/api/toyyibpay/return',
                'billCallbackUrl': f'{callback_base}/api/toyyibpay/webhook',
                'billExternalReferenceNo': f"{data['hubId']}|{data['tenantAdminId']}",
                'billTo': data['tenantAdminId'],
                'billEmail': data['billEmail'],
                'billPhone': data['billPhone'],
            },
            timeout=30,
        )
    except http_requests.RequestException as exc:
        logger.error('ToyyibPay unreachable: %s', exc)
        return jsonify({'error': 'ToyyibPay gateway unreachable'}), 502

    try:
        bill = resp.json()
        bill_code = bill[0]['BillCode']
    except (ValueError, KeyError, IndexError, TypeError):
        logger.error('ToyyibPay rejected bill: %s', resp.text[:300])
        return jsonify({'error': 'ToyyibPay rejected the bill request',
                        'detail': resp.text[:300]}), 502

    logger.info('Bill %s created for hub %s (%s cents)',
                bill_code, data['hubId'], amount_cents)
    return jsonify({
        'billUrl': f'{TOYYIBPAY_BASE_URL}/{bill_code}',
        'billCode': bill_code,
        'sandbox': False,
    })


@toyyibpay_bp.route('/api/toyyibpay/webhook', methods=['POST'])
def webhook():
    """ToyyibPay payment callback. status 1 = success."""
    form = request.form.to_dict() or (request.get_json(silent=True) or {})
    status = str(form.get('status', ''))
    ref = str(form.get('order_id') or form.get('billExternalReferenceNo') or '')
    hub_id = ref.split('|')[0] if ref else ''

    logger.info('Webhook received: status=%s hub=%s billcode=%s',
                status, hub_id, form.get('billcode', ''))

    # Amount arrives in cents; store both representations for auditing.
    raw_amount = str(form.get('amount', '') or '0')
    try:
        amount_rm = float(raw_amount) / 100.0
    except ValueError:
        amount_rm = 0.0

    _log_transaction({
        'gateway': 'toyyibpay',
        'parkingHubId': hub_id,
        'billCode': form.get('billcode', ''),
        'toyyibpayRefNo': form.get('refno', ''),
        'status': status,
        'amountCents': raw_amount,
        'amountRM': amount_rm,
        'transactionTime': form.get('transaction_time', ''),
        'raw': str(form)[:900],
        'success': status == '1',
    })

    # status: '1' = Success, '2' = Pending, '3' = Failed
    activated = False
    if status == '1' and hub_id:
        activated = _activate_hub(hub_id)
        if activated:
            logger.info('[SUCCESS] Hub %s reactivated via webhook.', hub_id)
        else:
            logger.error('[ERROR] Hub %s activation failed.', hub_id)
    elif status != '1':
        logger.warning('[FAILED/PENDING] Transaction %s status=%s.',
                       form.get('refno', ''), status)

    # Always 200 so ToyyibPay stops retrying; result carried in body.
    return jsonify({'ok': True, 'activated': activated})


@toyyibpay_bp.route('/api/toyyibpay/return', methods=['GET', 'POST'])
def payment_return():
    """Browser landing page after the FPX terminal closes."""
    status = request.values.get('status_id', '')
    if status == '1':
        return '<h2>✅ Pembayaran berjaya. Sistem anda akan diaktifkan dalam masa nyata. Anda boleh kembali ke aplikasi.</h2>'
    return '<h2>⚠️ Pembayaran tidak selesai. Sila cuba semula dari aplikasi.</h2>'
