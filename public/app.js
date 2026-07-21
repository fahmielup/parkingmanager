const API_BASE_URL = window.API_BASE_URL || '';

let currentSettings = {};
let currentReceipts = [];
let currentUser = null;
let trendChart = null;
let planChart = null;

function getToken() {
  return localStorage.getItem('jwt_token') || '';
}

function setToken(token) {
  localStorage.setItem('jwt_token', token);
}

function clearToken() {
  localStorage.removeItem('jwt_token');
}

function authHeaders(extra = {}) {
  const token = getToken();
  const headers = { ...extra };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  return headers;
}

async function apiFetch(url, options = {}) {
  const fullUrl = url.startsWith('http') ? url : `${API_BASE_URL}${url}`;
  const token = getToken();
  if (token && !options.headers) {
    options.headers = {};
  }
  if (token && options.headers && !options.headers['Authorization']) {
    options.headers['Authorization'] = `Bearer ${token}`;
  }
  const res = await fetch(fullUrl, options);
  if (res.status === 401) {
    clearToken();
    window.location.href = 'login.html';
    return { error: 'Unauthorized' };
  }
  if (res.status === 403) {
    showToast('Akses ditolak');
    return { error: 'Forbidden' };
  }
  return res;
}

const API = {
  async getMe() {
    const res = await apiFetch('/api/me');
    return res.json ? res.json() : res;
  },
  async getReceipts(filters = {}) {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([k, v]) => { if (v) params.append(k, v); });
    const res = await apiFetch(`/api/receipts?${params}`);
    return res.json ? res.json() : res;
  },
  async getReceipt(id) {
    const res = await apiFetch(`/api/receipts/${id}`);
    return res.json ? res.json() : res;
  },
  async createReceipt(data) {
    const res = await apiFetch('/api/receipts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async repairReceiptZones() {
    const res = await apiFetch('/api/receipts/repair-zones', { method: 'POST' });
    return res.json ? res.json() : res;
  },
  async updateReceipt(id, data) {
    const res = await apiFetch(`/api/receipts/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async deleteReceipt(id) {
    const res = await apiFetch(`/api/receipts/${id}`, { method: 'DELETE' });
    return res.json ? res.json() : res;
  },
  async storeWhatsAppReceipt(data) {
    const res = await apiFetch('/api/whatsapp-receipts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async uploadFile(file) {
    const formData = new FormData();
    formData.append('file', file);
    const res = await apiFetch('/api/upload', {
      method: 'POST',
      body: formData
    });
    return res.json ? res.json() : res;
  },
  async getSettings() {
    const res = await apiFetch('/api/settings');
    return res.json ? res.json() : res;
  },
  async saveSettings(settings) {
    const res = await apiFetch('/api/settings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(settings)
    });
    return res.json ? res.json() : res;
  },
  async getStats(zone = '') {
    const url = zone ? `/api/stats?zone=${zone}` : '/api/stats';
    const res = await apiFetch(url);
    return res.json ? res.json() : res;
  },
  async getUsers() {
    const res = await apiFetch('/api/users');
    return res.json ? res.json() : res;
  },
  async createUser(data) {
    const res = await apiFetch('/api/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async updateUser(id, data) {
    const res = await apiFetch(`/api/users/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async deleteUser(id) {
    const res = await apiFetch(`/api/users/${id}`, { method: 'DELETE' });
    return res.json ? res.json() : res;
  },
  async getAuditLogs() {
    const res = await apiFetch('/api/audit-logs');
    return res.json ? res.json() : res;
  },
  async createBackup() {
    const res = await apiFetch('/api/backup', { method: 'POST' });
    return res.json ? res.json() : res;
  },
  async getBackups() {
    const res = await apiFetch('/api/backups');
    return res.json ? res.json() : res;
  },
  async deleteBackup(name) {
    const res = await apiFetch(`/api/backups/${encodeURIComponent(name)}`, { method: 'DELETE' });
    return res.json ? res.json() : res;
  },
  async getCustomers(planType) {
    const res = await apiFetch(`/api/customers?planType=${planType}`);
    return res.json ? res.json() : res;
  },
  async getCustomerStats() {
    const res = await apiFetch('/api/customer-stats');
    return res.json ? res.json() : res;
  },
  async createCustomer(data) {
    const res = await apiFetch('/api/customers', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async updateCustomer(id, data) {
    const res = await apiFetch(`/api/customers/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async terminateCustomer(id, data) {
    const res = await apiFetch(`/api/customers/${id}/terminate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async deleteCustomer(id) {
    const res = await apiFetch(`/api/customers/${id}`, { method: 'DELETE' });
    return res.json ? res.json() : res;
  },
  async clearTerminatedCustomers() {
    const res = await apiFetch('/api/customers/terminated', { method: 'DELETE' });
    return res.json ? res.json() : res;
  },
  async getHistory() {
    const res = await apiFetch('/api/history');
    return res.json ? res.json() : res;
  },
  async clearHistory() {
    const res = await apiFetch('/api/history', { method: 'DELETE' });
    return res.json ? res.json() : res;
  },
  async getTransportCustomers(zone) {
    const res = await apiFetch(`/api/transport-customers?zone=${zone}`);
    return res.json ? res.json() : res;
  },
  async createTransportCustomer(data) {
    const res = await apiFetch('/api/transport-customers', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async updateTransportCustomer(id, data) {
    const res = await apiFetch(`/api/transport-customers/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    return res.json ? res.json() : res;
  },
  async deleteTransportCustomer(id) {
    const res = await apiFetch(`/api/transport-customers/${id}`, { method: 'DELETE' });
    return res.json ? res.json() : res;
  },
  async getTransportStats(zone) {
    const res = await apiFetch(`/api/transport-stats?zone=${zone}`);
    return res.json ? res.json() : res;
  }
};

const views = {
  dashboard: document.getElementById('view-dashboard'),
  receipts: document.getElementById('view-receipts'),
  create: document.getElementById('view-create'),
  whatsapp: document.getElementById('view-whatsapp'),
  'vista-tiara': document.getElementById('view-vista-tiara'),
  'vt-invoices': document.getElementById('view-vt-invoices'),
  'danga-bay': document.getElementById('view-danga-bay'),
  'db-invoices': document.getElementById('view-db-invoices'),
  'warung': document.getElementById('view-warung'),
  'warung-invoices': document.getElementById('view-warung-invoices'),
  settings: document.getElementById('view-settings'),
  users: document.getElementById('view-users'),
  audit: document.getElementById('view-audit'),
  backup: document.getElementById('view-backup'),
  history: document.getElementById('view-history')
};

const pageTitle = document.getElementById('page-title');
const navItems = document.querySelectorAll('.nav-item');
const toast = document.getElementById('toast');
const modal = document.getElementById('modal');
const modalBody = document.getElementById('modal-body');
const modalFooter = document.getElementById('modal-footer');
const modalTitle = document.getElementById('modal-title');

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 3000);
}

function showView(viewName) {
  Object.values(views).forEach(v => v.classList.remove('active'));
  views[viewName].classList.add('active');
  navItems.forEach(n => n.classList.remove('active'));
  const nav = document.querySelector(`[data-view="${viewName}"]`);
  if (nav) nav.classList.add('active');

  const titles = {
    dashboard: 'AMD Parking',
    receipts: 'Invoice AMD Parking',
    create: 'Buat Invoice Baru',
    whatsapp: 'Simpan Resit Bayaran',
    'vista-tiara': 'Vista Tiara Transport',
    'vt-invoices': 'Invoice Vista Tiara',
    'danga-bay': 'Danga Bay Transport',
    'db-invoices': 'Invoice Danga Bay',
    'warung': 'Penyewa Warung',
    'warung-invoices': 'Invoice Warung',
    settings: 'Tetapan',
    users: 'Pengurusan Pengguna',
    audit: 'Audit Log',
    backup: 'Backup Data',
    archives: 'Arkib Bulanan',
    history: 'History Record'
  };
  pageTitle.textContent = titles[viewName] || 'Parking Manager';

  if (viewName === 'dashboard' || viewName === 'receipts') loadReceipts();
  if (viewName === 'dashboard') { loadStats(); loadDashboardCustomers(); }
  if (viewName === 'vista-tiara') { loadTransportCustomers('vista-tiara'); loadZoneReceipts('vista-tiara'); }
  if (viewName === 'danga-bay') { loadTransportCustomers('danga-bay'); loadZoneReceipts('danga-bay'); }
  if (viewName === 'warung') { loadTransportCustomers('warung'); loadZoneReceipts('warung'); }
  if (viewName === 'vt-invoices') loadZoneInvoices('vista-tiara');
  if (viewName === 'db-invoices') loadZoneInvoices('danga-bay');
  if (viewName === 'warung-invoices') loadZoneInvoices('warung');
  if (viewName === 'users') loadUsers();
  if (viewName === 'audit') loadAuditLogs();
  if (viewName === 'backup') loadBackups();
  if (viewName === 'archives') loadArchives();
  if (viewName === 'history') loadHistory();

  document.querySelectorAll('.nav-group').forEach(g => {
    const hasActive = g.querySelector('.nav-item.active');
    if (hasActive) g.classList.remove('collapsed');
  });
}

document.querySelectorAll('.nav-group-header').forEach(header => {
  header.addEventListener('click', () => {
    const group = header.closest('.nav-group');
    group.classList.toggle('collapsed');
  });
});

navItems.forEach(item => {
  item.addEventListener('click', () => showView(item.dataset.view));
});

async function initUser() {
  try {
    currentUser = await API.getMe();
    if (currentUser.error) return;
    document.getElementById('user-info').textContent = `${currentUser.name} (${currentUser.role})`;
    document.querySelectorAll('.admin-only').forEach(el => {
      el.style.display = currentUser.role === 'admin' ? '' : 'none';
    });
  } catch (e) {
    console.error(e);
  }
}

async function loadSettings() {
  try {
    currentSettings = await API.getSettings();
    document.querySelector('[name="companyName"]').value = currentSettings.company_name || '';
    document.querySelector('[name="companyAddress"]').value = currentSettings.company_address || '';
    document.querySelector('[name="companyPhone"]').value = currentSettings.company_phone || '';
    document.querySelector('[name="companyEmail"]').value = currentSettings.company_email || '';
    document.querySelector('[name="companyRegNo"]').value = currentSettings.company_reg_no || '';
    document.querySelector('[name="bankAccount"]').value = currentSettings.bank_account || '';
    document.querySelector('[name="receiptTitle"]').value = currentSettings.receipt_title || 'PAYMENT RECEIPT';
    document.querySelector('[name="receiptFooter"]').value = currentSettings.receipt_footer || 'Thank you for your payment.';
    document.querySelector('[name="ratePerHour"]').value = currentSettings.rate_per_hour || '2.00';
    document.querySelector('[name="receiptsBasePath"]').value = currentSettings.receipts_base_path || '';
    document.querySelector('[name="companyLogo"]').value = currentSettings.company_logo || '';
    document.querySelector('[name="companyQrCode"]').value = currentSettings.company_qr_code || '';
    document.getElementById('company-logo-preview').innerHTML = currentSettings.company_logo ? `<img src="${currentSettings.company_logo}" style="max-width:120px;max-height:80px;">` : '';
    document.getElementById('company-qr-preview').innerHTML = currentSettings.company_qr_code ? `<img src="${currentSettings.company_qr_code}" style="max-width:120px;max-height:120px;">` : '';
  } catch (e) {
    console.error('Failed to load settings', e);
  }
}

async function loadStats() {
  try {
    const stats = await API.getStats('parking');
    const cstats = await API.getCustomerStats();
    document.getElementById('stat-revenue').textContent = stats.revenue.toFixed(2);
    document.getElementById('stat-invoice-revenue').textContent = (stats.invoice_revenue || 0).toFixed(2);
    document.getElementById('stat-active-monthly').textContent = cstats.active_monthly;
    document.getElementById('stat-active-daily').textContent = cstats.active_daily;
    document.getElementById('stat-terminated').textContent = cstats.terminated;
    if (currentUser && currentUser.role === 'admin') renderCharts(stats);
  } catch (e) {
    console.error(e);
  }
}

async function loadDashboardCustomers() {
  try {
    const monthly = await API.getCustomers('monthly');
    const daily = await API.getCustomers('daily');
    renderCustomerTable(monthly, 'monthly-customers', 'count-monthly');
    renderCustomerTable(daily, 'daily-customers', 'count-daily');
  } catch (e) {
    console.error(e);
    showToast('Ralat memuat senarai pelanggan');
  }
}

function renderCharts(stats) {
  if (trendChart) trendChart.destroy();
  if (planChart) planChart.destroy();

  const trendCtx = document.getElementById('trend-chart');
  if (trendCtx && stats.trend) {
    trendChart = new Chart(trendCtx, {
      type: 'line',
      data: {
        labels: stats.trend.map(t => t.date),
        datasets: [{
          label: 'Hasil (RM)',
          data: stats.trend.map(t => t.revenue),
          borderColor: '#2563eb',
          backgroundColor: 'rgba(37, 99, 235, 0.1)',
          fill: true,
          tension: 0.3
        }]
      },
      options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
    });
  }

  const planCtx = document.getElementById('plan-chart');
  if (planCtx && stats.plan_summary) {
    planChart = new Chart(planCtx, {
      type: 'doughnut',
      data: {
        labels: stats.plan_summary.map(p => p.plan === 'Monthly' ? 'Bulanan' : 'Harian'),
        datasets: [{
          data: stats.plan_summary.map(p => p.count),
          backgroundColor: ['#10b981', '#64748b']
        }]
      },
      options: { responsive: true }
    });
  }
}

async function loadReceipts() {
  try {
    const filters = {
      zone: 'parking',
      search: document.getElementById('search-input').value,
      status: document.getElementById('filter-status').value,
      source: document.getElementById('filter-source').value,
      plan: document.getElementById('filter-plan').value,
      month: document.getElementById('filter-month')?.value || '',
      dateFrom: document.getElementById('filter-date-from').value,
      dateTo: document.getElementById('filter-date-to').value
    };
    currentReceipts = await API.getReceipts(filters);
    renderReceiptsTable(currentReceipts);
    renderDashboard(currentReceipts);
  } catch (e) {
    console.error(e);
    showToast('Ralat memuat resit');
  }
}

function formatCurrency(value) {
  return parseFloat(value || 0).toFixed(2);
}

function formatDateTime(value) {
  if (!value) return '-';
  return new Date(value).toLocaleString('ms-MY', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function statusBadge(status) {
  const map = {
    'Selesai': 'badge-success',
    'Pending': 'badge-cancelled',
    'WhatsApp Received': 'badge-whatsapp'
  };
  return `<span class="badge ${map[status] || 'badge-system'}">${status || '-'}</span>`;
}

function sourceBadge(source) {
  return `<span class="badge ${source === 'WhatsApp' ? 'badge-whatsapp' : 'badge-system'}">${source}</span>`;
}

function planBadge(plan) {
  const monthly = ['Bulanan Parking', 'Bulanan + Transport', 'Berbumbung', 'Berbumbung + Transport'];
  const daily = ['Harian Parking', 'Harian + Transport', 'Transport Sahaja'];
  let cls = 'badge-system';
  if (monthly.includes(plan)) cls = 'badge-whatsapp';
  else if (daily.includes(plan)) cls = 'badge-active';
  return `<span class="badge ${cls}">${plan || '-'}</span>`;
}

function roleBadge(role) {
  return `<span class="badge ${role === 'admin' ? 'badge-whatsapp' : 'badge-system'}">${role === 'admin' ? 'Admin' : 'Manager'}</span>`;
}

function renderReceiptsTable(receipts) {
  const tbody = document.getElementById('receipts-table');
  tbody.innerHTML = '';
  if (!receipts.length) {
    tbody.innerHTML = '<tr><td colspan="9" style="text-align:center;padding:24px;">Tiada resit dijumpai</td></tr>';
    return;
  }
  receipts.forEach(r => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${r.receipt_number}</td>
      <td>${r.customer_name}</td>
      <td>${r.phone || '-'}</td>
      <td>${r.vehicle_number}</td>
      <td>${planBadge(r.plan)}</td>
      <td>${statusBadge(r.status)}</td>
      <td>${sourceBadge(r.source)}</td>
      <td>RM ${formatCurrency(r.amount)}</td>
      <td>
        <button class="btn btn-small btn-secondary btn-view" data-id="${r.id}">Lihat</button>
        <button class="btn btn-small btn-primary btn-print" data-id="${r.id}">Cetak</button>
        ${currentUser && currentUser.role === 'admin' ? `<button class="btn btn-small btn-danger btn-delete" data-id="${r.id}">Padam</button>` : ''}
      </td>
    `;
    tbody.appendChild(tr);
  });
  tbody.querySelectorAll('.btn-view').forEach(btn => btn.addEventListener('click', () => viewReceipt(parseInt(btn.dataset.id))));
  tbody.querySelectorAll('.btn-print').forEach(btn => btn.addEventListener('click', () => printReceipt(parseInt(btn.dataset.id))));
  tbody.querySelectorAll('.btn-delete').forEach(btn => btn.addEventListener('click', () => deleteReceipt(parseInt(btn.dataset.id))));
}

function renderDashboard(receipts) {
  const tbody = document.getElementById('dashboard-receipts');
  tbody.innerHTML = '';
  const latest = receipts.slice(0, 10);
  if (!latest.length) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:24px;">Tiada resit</td></tr>';
    return;
  }
  latest.forEach(r => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${r.receipt_number}</td>
      <td>${r.customer_name}</td>
      <td>${r.vehicle_number}</td>
      <td>${planBadge(r.plan)}</td>
      <td>RM ${formatCurrency(r.amount)}</td>
      <td>${formatDateTime(r.created_at)}</td>
    `;
    tbody.appendChild(tr);
  });
}

function renderCustomerTable(customers, tbodyId, countId) {
  const tbody = document.getElementById(tbodyId);
  if (countId) document.getElementById(countId).textContent = customers.length;
  tbody.innerHTML = '';
  if (!customers.length) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:24px;">Tiada rekod</td></tr>';
    return;
  }
  customers.forEach(c => {
    const isMonthly = ['Bulanan Parking', 'Bulanan + Transport', 'Berbumbung', 'Berbumbung + Transport'].includes(c.plan);
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${c.customer_name}</td>
      <td>${c.vehicle_number}</td>
      <td>${planBadge(c.plan)}</td>
      <td>${isMonthly ? formatDate(c.end_date) : formatDate(c.last_payment_date)}</td>
      <td>${statusBadge(c.status)}</td>
      <td>
        <button class="btn btn-small btn-secondary btn-edit-customer" data-id="${c.id}">Edit</button>
        ${c.status === 'Active' ? `<button class="btn btn-small btn-danger btn-terminate-customer" data-id="${c.id}">Tamat</button>` : ''}
      </td>
    `;
    tbody.appendChild(tr);
  });
  tbody.querySelectorAll('.btn-edit-customer').forEach(btn => btn.addEventListener('click', () => openCustomerModal(parseInt(btn.dataset.id))));
  tbody.querySelectorAll('.btn-terminate-customer').forEach(btn => btn.addEventListener('click', () => terminateCustomer(parseInt(btn.dataset.id))));
}

function formatDate(value) {
  if (!value) return '-';
  return new Date(value).toLocaleDateString('ms-MY', { day: '2-digit', month: 'short', year: 'numeric' });
}

function fmtReceiptDate(val) {
  if (!val) return '-';
  const d = new Date(val);
  if (isNaN(d)) return val;
  return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' }).toUpperCase();
}

function setZonePaymentDates() {
  const now = new Date();
  const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  document.querySelectorAll('.zone-payment-date').forEach(input => {
    input.value = today;
  });
}

function receiptHtml(r) {
  const logo = currentSettings.company_logo ? `<img src="${currentSettings.company_logo}" class="receipt-logo">` : '';
  const qr = currentSettings.company_qr_code ? `<img src="${currentSettings.company_qr_code}" class="receipt-qr">` : '';
  const companyName = (currentSettings.company_name || 'Parking Manager').toUpperCase();
  const receiptTitle = (currentSettings.receipt_title || 'PAYMENT RECEIPT').toUpperCase();
  const paymentDate = fmtReceiptDate(r.payment_date);
  const arriveDate = r.entry_time ? fmtReceiptDate(r.entry_time) : '-';
  const departDate = r.exit_time ? fmtReceiptDate(r.exit_time) : '-';
  const total = r.amount ? r.amount.toFixed(2) : '0.00';
  const unitPrice = total;
  const footer = currentSettings.receipt_footer || 'FOR ONLINE TRANSFER USE, THANK YOU.';
  const email = currentSettings.company_email || '';
  const phone = currentSettings.company_phone || '';
  const bankAccount = currentSettings.bank_account || '';
  const billedTo = (r.vehicle_number || r.customer_name || '-').toUpperCase();
  const planDesc = (r.plan || 'Parking').toUpperCase();
  const notesRaw = r.notes ? r.notes.replace(/\s*\|?\s*Diskaun:\s*RM[\d.]+/gi, '').trim() : '';
  const notesDesc = notesRaw ? notesRaw.toUpperCase() : '';

  const hasEntryExit = r.entry_time && r.exit_time;
  const infoRight = hasEntryExit
    ? `<div><strong>ARRIVE:</strong>&nbsp; ${arriveDate}</div><div><strong>DEPART:</strong>&nbsp; ${departDate}</div>`
    : `<div><strong>PAYMENT:</strong>&nbsp; ${paymentDate}</div>`;

  return `
    <div class="receipt-a4">
      <div class="receipt-outer-border">
        <div class="receipt-header">
          <div class="receipt-logo-area">${logo}</div>
          <div class="receipt-title-area">
            <h2 class="receipt-main-title">${receiptTitle}</h2>
            <div class="receipt-company">${companyName}</div>
          </div>
        </div>
        <div class="receipt-divider"></div>
        <div class="receipt-info">
          <div class="receipt-info-left">
            <div><strong>RECEIPT NO:</strong>&nbsp; ${r.receipt_number || ''}</div>
            <div><strong>BILLED TO:</strong>&nbsp; ${billedTo}</div>
            <div><strong>ADDRESS:</strong></div>
          </div>
          <div class="receipt-info-right">
            ${infoRight}
          </div>
        </div>
        <div class="receipt-divider"></div>
        <table class="receipt-table">
          <thead>
            <tr>
              <th>DESCRIPTION</th>
              <th>QTY.</th>
              <th>UNIT PRICE</th>
              <th>TOTAL</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td style="text-align:center;">${planDesc}</td>
              <td></td>
              <td style="text-align:center;">${unitPrice}</td>
              <td style="text-align:center;">${total}</td>
            </tr>
            ${notesDesc ? `<tr><td style="text-align:center;">${notesDesc}</td><td></td><td></td><td></td></tr>` : '<tr><td></td><td></td><td></td><td></td></tr>'}
            <tr><td></td><td></td><td></td><td></td></tr>
            <tr><td></td><td></td><td></td><td></td></tr>
            <tr><td></td><td></td><td></td><td></td></tr>
            <tr><td></td><td></td><td></td><td></td></tr>
          </tbody>
        </table>
        <div class="receipt-bottom">
          <div class="receipt-bottom-left">
            <div><strong>PAYMENT METHOD:</strong>&nbsp; ${(r.payment_method || '-').toUpperCase()}</div>
            <div><strong>TRANSACTION ID:</strong></div>
            <div><strong>NOTES:</strong></div>
            <div class="receipt-signature-block">
              <div class="receipt-sig-label">SIGNATURE</div>
              <img src="uploads/cop_amd.jpg" class="receipt-stamp-img" alt="stamp">
            </div>
          </div>
          <div class="receipt-bottom-right">
            <div class="receipt-total-rows">
              <div class="receipt-total-row"><span>SUB-TOTAL:</span><span class="receipt-total-line-val"></span></div>
              <div class="receipt-total-row"><span></span><span class="receipt-total-line-val"></span></div>
              <div class="receipt-total-row receipt-grand-total"><span>TOTAL:</span><span>${total}</span></div>
            </div>
            <div class="receipt-qr-block">
              <div class="receipt-qr-img">${qr}</div>
              <div class="receipt-qr-caption">${bankAccount}</div>
              <div class="receipt-qr-note">${footer}</div>
            </div>
          </div>
        </div>
        <div class="receipt-footer-bar">
          <em>For appointments or inquiries, reach out to us at ${email}${email && phone ? ' or ' : ''}${phone ? '&#128241; ' + phone : ''}</em>
        </div>
      </div>
    </div>`;
}

async function downloadReceiptPng(receiptNumber, receiptId) {
  const el = document.querySelector('.receipt-a4');
  if (!el) { showToast('Tiada resit untuk dimuat turun'); return; }
  showToast('Menyediakan PNG...');
  try {
    const canvas = await html2canvas(el, { scale: 2, useCORS: true, backgroundColor: '#ffffff' });
    const dataUrl = canvas.toDataURL('image/png');
    const link = document.createElement('a');
    link.download = `Resit-${receiptNumber || 'invoice'}.png`;
    link.href = dataUrl;
    link.click();
    if (receiptId) {
      try {
        const res = await fetch(`${API_BASE_URL}/api/receipts/${receiptId}/save-png`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${getToken()}` },
          body: JSON.stringify({ imageData: dataUrl })
        });
        const result = await res.json();
        if (result.success) {
          showToast(`PNG disimpan: ${result.folder}`);
        }
      } catch (saveErr) {
        console.error('Save PNG error:', saveErr);
      }
    } else {
      showToast('PNG berjaya dimuat turun');
    }
  } catch (e) {
    console.error(e);
    showToast('Ralat: gagal jana PNG');
  }
}

async function viewReceipt(id) {
  const r = await API.getReceipt(id);
  if (r.error) { showToast('Ralat: ' + r.error); return; }
  modalTitle.textContent = `Invoice ${r.receipt_number}`;
  let filePreview = '';
  if (r.file_path) {
    filePreview = `<div style="margin-top:16px;text-align:center;"><p>Resit Bayaran:</p><div id="preview-container">Loading...</div></div>`;
  }
  modalBody.innerHTML = receiptHtml(r) + filePreview;
  modalFooter.innerHTML = `
    <button class="btn btn-secondary modal-close-btn">Tutup</button>
    <button class="btn btn-secondary" id="modal-dl-btn">&#8681; Download PNG</button>
    <button class="btn btn-primary" id="modal-print-btn">Cetak</button>`;
  modal.classList.add('active');
  modalFooter.querySelector('#modal-print-btn').addEventListener('click', () => printReceipt(id));
  modalFooter.querySelector('#modal-dl-btn').addEventListener('click', () => downloadReceiptPng(r.receipt_number, r.id));
  modalFooter.querySelector('.modal-close-btn').addEventListener('click', closeModal);
  if (r.file_path) loadFilePreview(r.file_path, 'preview-container');
}

async function loadFilePreview(filePath, containerId) {
  try {
    const container = document.getElementById(containerId);
    if (!container) return;
    const encodedPath = encodeURIComponent(filePath);
    const token = getToken();
    const ext = filePath.split('.').pop().toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(ext)) {
      container.innerHTML = `<img src="${API_BASE_URL}/api/files/${encodedPath}?token=${token}" style="max-width:100%;max-height:300px;border-radius:8px;" />`;
    } else if (ext === 'pdf') {
      container.innerHTML = `<embed src="${API_BASE_URL}/api/files/${encodedPath}?token=${token}" type="application/pdf" width="100%" height="300px" />`;
    } else {
      container.innerHTML = `<a href="${API_BASE_URL}/api/files/${encodedPath}?token=${token}" target="_blank" class="btn btn-secondary">Buka Fail</a>`;
    }
  } catch (e) { console.error(e); }
}

async function printReceipt(id) {
  const r = await API.getReceipt(id);
  if (r.error) { showToast('Ralat: ' + r.error); return; }
  modalTitle.textContent = 'Invoice Parking';
  modalBody.innerHTML = receiptHtml(r);
  modalFooter.innerHTML = `
    <button class="btn btn-secondary modal-close-btn">Tutup</button>
    <button class="btn btn-secondary" id="modal-dl-btn2">&#8681; Download PNG</button>
    <button class="btn btn-primary" onclick="window.print()">Cetak Sekarang</button>`;
  modal.classList.add('active');
  modalFooter.querySelector('.modal-close-btn').addEventListener('click', closeModal);
  modalFooter.querySelector('#modal-dl-btn2').addEventListener('click', () => downloadReceiptPng(r.receipt_number, r.id));
}

async function deleteReceipt(id) {
  if (!confirm('Padam invoice ini? Tindakan ini tidak boleh dibuat semula.')) return;
  const result = await API.deleteReceipt(id);
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  showToast('Invoice telah dipadam');
  const activeView = document.querySelector('.view.active');
  if (activeView) {
    const viewId = activeView.id;
    if (viewId === 'view-vt-invoices') loadZoneInvoices('vista-tiara');
    else if (viewId === 'view-db-invoices') loadZoneInvoices('danga-bay');
    else if (viewId === 'view-warung-invoices') loadZoneInvoices('warung');
    else if (viewId === 'view-vista-tiara') { loadZoneReceipts('vista-tiara'); loadTransportCustomers('vista-tiara'); }
    else if (viewId === 'view-danga-bay') { loadZoneReceipts('danga-bay'); loadTransportCustomers('danga-bay'); }
    else if (viewId === 'view-warung') { loadZoneReceipts('warung'); loadTransportCustomers('warung'); }
    else loadReceipts();
  } else {
    loadReceipts();
  }
}

function closeModal() {
  modal.classList.remove('active');
  modalBody.innerHTML = '';
  modalFooter.innerHTML = '';
}

document.getElementById('modal-close').addEventListener('click', closeModal);
modal.addEventListener('click', (e) => { if (e.target === modal) closeModal(); });

// --- Tab switching logic ---
document.querySelectorAll('.invoice-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.invoice-tab').forEach(t => t.classList.remove('active'));
    tab.classList.add('active');
    document.querySelectorAll('#view-create .tab-content').forEach(c => c.classList.remove('active'));
    const target = tab.dataset.tab;
    const formMap = { 'parking': 'create-form-parking', 'vista-tiara': 'create-form-vt', 'danga-bay': 'create-form-db', 'warung': 'create-form-warung' };
    const form = document.getElementById(formMap[target]);
    if (form) form.classList.add('active');
    if (target === 'parking') updateKadarHint();
  });
});

// --- Parking form submit ---
document.getElementById('create-form-parking').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const data = Object.fromEntries(new FormData(form).entries());
  if (!data.customerName) data.customerName = data.vehicleNumber || '';
  if (!data.ratePerHour) data.ratePerHour = currentSettings.rate_per_hour || '18.00';
  const discount = parseFloat(data.discount) || 0;
  if (discount > 0 && !data.notes) {
    data.notes = `Diskaun: RM${discount.toFixed(2)}`;
  } else if (discount > 0 && data.notes) {
    data.notes = data.notes + ` | Diskaun: RM${discount.toFixed(2)}`;
  }
  const entry = data.entryTime ? new Date(data.entryTime) : null;
  const exit = data.exitTime ? new Date(data.exitTime) : null;
  if (entry && exit && !isNaN(entry) && !isNaN(exit)) {
    const diffMs = exit - entry;
    const days = Math.max(1, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
    data.durationMinutes = days * 24 * 60;
  }
  const result = await API.createReceipt(data);
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  showToast('Invoice berjaya disimpan');
  form.reset();
  updateKadarHint();
  printReceipt(result.receipt.id);
  loadReceipts();
  loadStats();
});

// --- Vista Tiara form submit ---
document.getElementById('create-form-vt').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const data = Object.fromEntries(new FormData(form).entries());
  data.vehicleNumber = data.customerName || '-';
  data.ratePerHour = '0';
  data.plan = 'VT Transport Bulanan';
  const pax = parseInt(data.pax) || 1;
  if (pax > 1 && !data.notes) {
    data.notes = `${pax} pax (1st: RM360, ${pax - 1}x RM180)`;
  } else if (pax > 1 && data.notes) {
    data.notes = data.notes + ` | ${pax} pax (1st: RM360, ${pax - 1}x RM180)`;
  }
  const result = await API.createReceipt(data);
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  showToast('Invoice berjaya disimpan');
  form.reset();
  setZonePaymentDates();
  calcVTTotal();
  printReceipt(result.receipt.id);
  loadReceipts();
  loadStats();
});

// --- Danga Bay form submit ---
document.getElementById('create-form-db').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const data = Object.fromEntries(new FormData(form).entries());
  data.vehicleNumber = data.customerName || '-';
  data.ratePerHour = '0';
  data.plan = 'DB Transport Bulanan';
  const pax = parseInt(data.pax) || 1;
  if (pax > 1 && !data.notes) {
    data.notes = `${pax} pax (1st: RM400, ${pax - 1}x RM180)`;
  } else if (pax > 1 && data.notes) {
    data.notes = data.notes + ` | ${pax} pax (1st: RM400, ${pax - 1}x RM180)`;
  }
  const result = await API.createReceipt(data);
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  showToast('Invoice berjaya disimpan');
  form.reset();
  setZonePaymentDates();
  calcDBTotal();
  printReceipt(result.receipt.id);
  loadReceipts();
  loadStats();
});

// --- Warung form submit ---
document.getElementById('create-form-warung').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const data = Object.fromEntries(new FormData(form).entries());
  data.vehicleNumber = data.customerName || '-';
  data.ratePerHour = '0';
  data.plan = 'Warung Bulanan';
  const result = await API.createReceipt(data);
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  showToast('Invoice berjaya disimpan');
  form.reset();
  setZonePaymentDates();
  calcWgTotal();
  printReceipt(result.receipt.id);
  loadReceipts();
  loadStats();
});

// --- VT/DB/Warung auto-calc functions ---
function calcVTTotal() {
  const pax = parseInt(document.getElementById('vt-pax').value) || 1;
  const total = 360 + (pax > 1 ? (pax - 1) * 180 : 0);
  document.getElementById('vt-amount').value = total.toFixed(2);
  const hint = document.getElementById('vt-hint');
  if (hint) hint.textContent = pax > 1 ? `(1st RM360 + ${pax - 1}x RM180 = RM${total.toFixed(2)})` : '(1 pax: RM360)';
}

function calcDBTotal() {
  const pax = parseInt(document.getElementById('db-pax').value) || 1;
  const total = 400 + (pax > 1 ? (pax - 1) * 180 : 0);
  document.getElementById('db-amount').value = total.toFixed(2);
  const hint = document.getElementById('db-hint');
  if (hint) hint.textContent = pax > 1 ? `(1st RM400 + ${pax - 1}x RM180 = RM${total.toFixed(2)})` : '(1 pax: RM400)';
}

function calcWgTotal() {
  document.getElementById('wg-amount').value = '400.00';
}

document.getElementById('vt-pax').addEventListener('input', calcVTTotal);
document.getElementById('db-pax').addEventListener('input', calcDBTotal);
document.getElementById('wg-pax').addEventListener('input', calcWgTotal);
calcVTTotal();
calcDBTotal();
calcWgTotal();
setZonePaymentDates();

document.getElementById('whatsapp-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const fileInput = document.getElementById('wa-file');
  if (!fileInput.files.length) { showToast('Sila pilih gambar/PDF resit bayaran'); return; }
  const file = fileInput.files[0];
  const reader = new FileReader();
  reader.onload = async (evt) => {
    const data = Object.fromEntries(new FormData(form).entries());
    data.fileData = evt.target.result;
    data.fileName = file.name;
    const result = await API.storeWhatsAppReceipt(data);
    if (result.error) { showToast('Ralat: ' + result.error); return; }
    showToast('Resit Bayaran berjaya disimpan');
    form.reset();
    loadReceipts();
    loadStats();
  };
  reader.readAsDataURL(file);
});

document.getElementById('settings-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const data = Object.fromEntries(new FormData(form).entries());
  const settings = {
    company_name: data.companyName,
    company_address: data.companyAddress,
    company_phone: data.companyPhone,
    company_email: data.companyEmail,
    company_reg_no: data.companyRegNo,
    bank_account: data.bankAccount,
    receipt_title: data.receiptTitle,
    receipt_footer: data.receiptFooter,
    rate_per_hour: data.ratePerHour,
    receipts_base_path: data.receiptsBasePath || '',
    company_logo: data.companyLogo || '',
    company_qr_code: data.companyQrCode || ''
  };
  const result = await API.saveSettings(settings);
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  currentSettings = result.settings;
  showToast('Tetapan disimpan');
});

async function handleImageUpload(inputId, hiddenInputName, previewId) {
  const input = document.getElementById(inputId);
  if (!input) return;
  input.addEventListener('change', async () => {
    const file = input.files[0];
    if (!file) return;
    if (file.size > 2 * 1024 * 1024) {
      showToast('Saiz fail terlalu besar (maks 2MB)');
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = reader.result;
      document.querySelector(`[name="${hiddenInputName}"]`).value = dataUrl;
      document.getElementById(previewId).innerHTML = `<img src="${dataUrl}" style="max-width:120px;max-height:120px;">`;
      showToast('Gambar berjaya dimuat naik');
    };
    reader.onerror = () => showToast('Ralat memuat naik gambar');
    reader.readAsDataURL(file);
  });
}

handleImageUpload('company-logo-input', 'companyLogo', 'company-logo-preview');
handleImageUpload('company-qr-input', 'companyQrCode', 'company-qr-preview');

document.getElementById('logout-btn').addEventListener('click', async () => {
  await apiFetch('/api/logout', { method: 'POST' });
  clearToken();
  window.location.href = '/login.html';
});

function getSelectedPlanType() {
  const sel = document.getElementById('create-plan-parking');
  if (!sel) return { type: 'fixed', amount: 0 };
  const opt = sel.selectedOptions[0];
  return { type: opt.dataset.type || 'fixed', amount: parseFloat(opt.dataset.amount) || 0 };
}

function updateKadarHint() {
  const { type, amount } = getSelectedPlanType();
  const kadarInput = document.getElementById('kadar-input');
  const hint = document.getElementById('kadar-hint');
  const kadarGroup = document.getElementById('kadar-group');
  if (!kadarInput || !hint) return;
  if (type === 'daily') {
    kadarInput.value = amount;
    hint.textContent = '(harian — didarab dengan bilangan hari)';
    kadarGroup.style.display = '';
  } else {
    kadarInput.value = amount;
    hint.textContent = '(tetap — tidak didarab hari)';
    kadarGroup.style.display = '';
  }
}

function calcTotal() {
  const form = document.getElementById('create-form-parking');
  if (!form) return;
  const { type } = getSelectedPlanType();
  const rate = parseFloat(form.ratePerHour ? form.ratePerHour.value : 0) || 0;
  const discount = parseFloat(document.getElementById('diskaun-input') ? document.getElementById('diskaun-input').value : 0) || 0;
  let subtotal = rate;
  let msg = '';
  if (type === 'daily') {
    const entry = form.entryTime.value ? new Date(form.entryTime.value) : null;
    const exit = form.exitTime.value ? new Date(form.exitTime.value) : null;
    let days = 1;
    if (entry && exit && !isNaN(entry) && !isNaN(exit)) {
      const diffMs = exit - entry;
      days = Math.max(1, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
    }
    subtotal = rate * days;
    msg = `${days} hari x RM${rate.toFixed(2)} = RM${subtotal.toFixed(2)}`;
  } else {
    msg = `Pakej tetap: RM${rate.toFixed(2)}`;
  }
  const total = Math.max(0, subtotal - discount);
  if (discount > 0) msg += ` - Diskaun RM${discount.toFixed(2)} = RM${total.toFixed(2)}`;
  form.amount.value = total.toFixed(2);
  showToast('Jumlah: RM' + total.toFixed(2) + ' (' + msg + ')');
}

const createPlanSel = document.getElementById('create-plan-parking');
if (createPlanSel) {
  createPlanSel.addEventListener('change', () => {
    updateKadarHint();
  });
  updateKadarHint();
}

const waPlanSel = document.getElementById('wa-plan');
if (waPlanSel) {
  waPlanSel.addEventListener('change', () => {
    const amount = waPlanSel.selectedOptions[0].dataset.amount;
    if (amount) document.querySelector('[name="amount"]', document.getElementById('whatsapp-form')) && (document.getElementById('whatsapp-form').querySelector('[name="amount"]').value = amount);
  });
  waPlanSel.dispatchEvent(new Event('change'));
}

document.getElementById('btn-auto-calc').addEventListener('click', calcTotal);

document.getElementById('btn-search').addEventListener('click', loadReceipts);
document.getElementById('btn-export').addEventListener('click', () => {
  const token = getToken();
  fetch(`${API_BASE_URL}/api/export/csv`, {
    headers: { 'Authorization': `Bearer ${token}` }
  }).then(res => res.blob()).then(blob => {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `invoices_export_${new Date().toISOString().slice(0,10)}.csv`;
    a.click();
  });
});

document.getElementById('refresh-btn').addEventListener('click', () => {
  loadReceipts();
  loadStats();
});

document.getElementById('user-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const errorDiv = document.getElementById('user-form-error');
  const data = Object.fromEntries(new FormData(form).entries());
  if (!data.password || data.password.length < 6) {
    errorDiv.textContent = 'Kata laluan mesti sekurang-kurangnya 6 aksara.';
    errorDiv.style.display = 'block';
    return;
  }
  errorDiv.style.display = 'none';
  const result = await API.createUser(data);
  if (result.error) {
    errorDiv.textContent = 'Ralat: ' + result.error;
    errorDiv.style.display = 'block';
    return;
  }
  errorDiv.style.display = 'none';
  showToast('Pengguna berjaya ditambah');
  form.reset();
  loadUsers();
});

document.getElementById('btn-backup').addEventListener('click', async () => {
  const result = await API.createBackup();
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  showToast('Backup berjaya dibuat: ' + result.backup_name);
  loadBackups();
});

document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeModal(); });

async function loadUsers() {
  if (!currentUser || currentUser.role !== 'admin') return;
  try {
    const users = await API.getUsers();
    const tbody = document.getElementById('users-table');
    tbody.innerHTML = '';
    if (!users.length) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:24px;">Tiada pengguna</td></tr>';
      return;
    }
    users.forEach(u => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${u.name || '-'}</td>
        <td>${u.username}</td>
        <td>${roleBadge(u.role)}</td>
        <td>${u.active ? 'Aktif' : 'Tidak Aktif'}</td>
        <td>${formatDateTime(u.created_at)}</td>
        <td>
          <button class="btn btn-small btn-secondary btn-reset-pw" data-id="${u.id}">Reset Kata Laluan</button>
          <button class="btn btn-small btn-danger btn-delete-user" data-id="${u.id}">Padam</button>
        </td>`;
      tbody.appendChild(tr);
    });
    tbody.querySelectorAll('.btn-reset-pw').forEach(btn => {
      btn.addEventListener('click', async () => {
        const newPw = prompt('Masukkan kata laluan baru (minimum 6 aksara):');
        if (!newPw || newPw.length < 6) { showToast('Kata laluan terlalu pendek'); return; }
        const result = await API.updateUser(parseInt(btn.dataset.id), { password: newPw });
        if (result.error) { showToast('Ralat: ' + result.error); return; }
        showToast('Kata laluan berjaya ditukar');
      });
    });
    tbody.querySelectorAll('.btn-delete-user').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('Padam pengguna ini?')) return;
        const result = await API.deleteUser(parseInt(btn.dataset.id));
        if (result.error) { showToast('Ralat: ' + result.error); return; }
        showToast('Pengguna dipadam');
        loadUsers();
      });
    });
  } catch (e) { console.error(e); }
}

async function loadAuditLogs() {
  if (!currentUser || currentUser.role !== 'admin') return;
  try {
    const logs = await API.getAuditLogs();
    const tbody = document.getElementById('audit-table');
    tbody.innerHTML = '';
    if (!logs.length) {
      tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;padding:24px;">Tiada rekod</td></tr>';
      return;
    }
    logs.forEach(l => {
      const tr = document.createElement('tr');
      let details = '-';
      try { details = l.details ? JSON.parse(l.details).username || JSON.stringify(JSON.parse(l.details)) : '-'; } catch (e) { details = l.details || '-'; }
      tr.innerHTML = `
        <td>${formatDateTime(l.created_at)}</td>
        <td>${l.username || '-'}</td>
        <td>${l.action}</td>
        <td>${details}</td>
        <td>${l.ip_address || '-'}</td>`;
      tbody.appendChild(tr);
    });
  } catch (e) { console.error(e); }
}

async function loadBackups() {
  if (!currentUser || currentUser.role !== 'admin') return;
  try {
    const backups = await API.getBackups();
    const tbody = document.getElementById('backup-table');
    tbody.innerHTML = '';
    if (!backups.length) {
      tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;padding:24px;">Tiada backup</td></tr>';
      return;
    }
    backups.forEach(b => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${b.name}</td>
        <td>${(b.size / 1024).toFixed(1)} KB</td>
        <td>${formatDateTime(b.created)}</td>
        <td>
          <a href="/api/backups/${encodeURIComponent(b.name)}" class="btn btn-small btn-secondary" download>Muat Turun</a>
          <button class="btn btn-small btn-danger btn-delete-backup" data-name="${b.name}">Padam</button>
        </td>`;
      tbody.appendChild(tr);
    });
    tbody.querySelectorAll('.btn-delete-backup').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('Padam backup ini?')) return;
        const result = await API.deleteBackup(btn.dataset.name);
        if (result.error) { showToast('Ralat: ' + result.error); return; }
        showToast('Backup dipadam');
        loadBackups();
      });
    });
  } catch (e) { console.error(e); }
}

async function loadHistory() {
  if (!currentUser || currentUser.role !== 'admin') return;
  try {
    const records = await API.getHistory();
    const tbody = document.getElementById('history-table');
    tbody.innerHTML = '';
    if (!records.length) {
      tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;padding:24px;">Tiada rekod history</td></tr>';
      return;
    }
    records.forEach(r => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${formatDateTime(r.terminated_at)}</td>
        <td>${r.customer_name}</td>
        <td>${r.vehicle_number}</td>
        <td>${planBadge(r.plan)}</td>
        <td>${r.end_date || '-'}</td>
        <td>${r.terminated_by_name || '-'}</td>
        <td>${r.notes || '-'}</td>`;
      tbody.appendChild(tr);
    });
  } catch (e) { console.error(e); }
}

const customerModal = document.getElementById('customer-modal');
const customerModalTitle = document.getElementById('customer-modal-title');
const customerForm = document.getElementById('customer-form');

function openCustomerModal(customerId = null) {
  customerForm.reset();
  customerForm.customerId.value = customerId || '';
  customerModalTitle.textContent = customerId ? 'Edit Pelanggan' : 'Tambah Pelanggan';
  if (customerId) {
    fetch(`${API_BASE_URL}/api/customers/${customerId}`, { headers: { 'Authorization': `Bearer ${getToken()}` } }).then(res => res.json()).then(c => {
      customerForm.customerName.value = c.customer_name || '';
      customerForm.customerPhone.value = c.phone || '';
      customerForm.vehicleNumber.value = c.vehicle_number || '';
      customerForm.customerPlan.value = c.plan || 'Harian Parking';
      customerForm.customerStatus.value = c.status || 'Active';
      customerForm.startDate.value = c.start_date || '';
      customerForm.endDate.value = c.end_date || '';
      customerForm.monthlyRate.value = c.monthly_rate || 0;
      customerForm.customerNotes.value = c.notes || '';
    });
  }
  customerModal.classList.add('active');
}

function closeCustomerModal() {
  customerModal.classList.remove('active');
}

async function terminateCustomer(id) {
  if (!confirm('Tamatkan tempahan pelanggan ini?')) return;
  const result = await API.terminateCustomer(id, {});
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  showToast('Tempahan pelanggan telah ditamatkan');
  loadDashboardCustomers();
  loadStats();
}

document.getElementById('customer-modal-close').addEventListener('click', closeCustomerModal);
customerModal.addEventListener('click', (e) => { if (e.target === customerModal) closeCustomerModal(); });

customerForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const data = Object.fromEntries(new FormData(customerForm).entries());
  const payload = {
    customerName: data.customerName,
    phone: data.customerPhone,
    vehicleNumber: data.vehicleNumber,
    plan: data.customerPlan,
    status: data.customerStatus,
    startDate: data.startDate,
    endDate: data.endDate,
    monthlyRate: data.monthlyRate,
    notes: data.customerNotes
  };
  const id = data.customerId;
  const result = id ? await API.updateCustomer(id, payload) : await API.createCustomer(payload);
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  showToast(id ? 'Pelanggan dikemaskini' : 'Pelanggan ditambah');
  closeCustomerModal();
  loadDashboardCustomers();
  loadStats();
});

document.getElementById('btn-add-customer').addEventListener('click', () => openCustomerModal());
document.getElementById('btn-receipts-view').addEventListener('click', () => showView('receipts'));

const btnClearTerminated = document.getElementById('btn-clear-terminated');
if (btnClearTerminated) {
  btnClearTerminated.addEventListener('click', async () => {
    if (!confirm('Padam semua kereta harian dan bulanan dengan status Terminated?')) return;
    const result = await API.clearTerminatedCustomers();
    if (result.error) { showToast('Ralat: ' + result.error); return; }
    showToast(`${result.deleted || 0} rekod terminated telah dipadam`);
    loadDashboardCustomers();
    loadStats();
  });
}

const btnRepairReceiptZones = document.getElementById('btn-repair-receipt-zones');
if (btnRepairReceiptZones) {
  btnRepairReceiptZones.addEventListener('click', async () => {
    if (!confirm('Pindahkan invoice Harian Parking yang sepadan dengan harga Vista Tiara dan Danga Bay? Tindakan ini tidak boleh dibatalkan secara automatik.')) return;
    const result = await API.repairReceiptZones();
    if (result.error) { showToast('Ralat: ' + result.error); return; }
    showToast(`Invoice dipindahkan — Vista Tiara: ${result.vista_tiara || 0}, Danga Bay: ${result.danga_bay || 0}`);
    loadReceipts();
    loadStats();
  });
}

const btnClearHistory = document.getElementById('btn-clear-history');
if (btnClearHistory) {
  btnClearHistory.addEventListener('click', async () => {
    if (!confirm('Padam semua rekod history? Tindakan ini tidak boleh dibuat semula.')) return;
    const result = await API.clearHistory();
    if (result.error) { showToast('Ralat: ' + result.error); return; }
    showToast('Semua rekod history telah dipadam');
    loadHistory();
  });
}

document.getElementById('customer-plan').addEventListener('change', () => {
  const select = document.getElementById('customer-plan');
  const amount = select.selectedOptions[0].dataset.amount || 0;
  customerForm.monthlyRate.value = amount;
});

setInterval(() => {
  apiFetch('/api/me').then(res => {
    if (res.error) { /* already redirected in apiFetch */ }
  });
}, 60000);

window.addEventListener('DOMContentLoaded', async () => {
  await initUser();
  loadSettings();
  loadReceipts();
  loadStats();
  loadMonths();
  document.getElementById('search-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') loadReceipts();
  });
});

// ===== Transport Customers (Vista Tiara & Danga Bay) =====
const transportModal = document.getElementById('transport-modal');
const transportForm = document.getElementById('transport-form');
let currentTransportZone = '';

function openTransportModal(zone, customer = null) {
  currentTransportZone = zone;
  document.getElementById('transport-zone').value = zone;
  document.getElementById('transport-modal-title').textContent =
    zone === 'vista-tiara' ? 'Pelanggan Vista Tiara Transport' : 'Pelanggan Danga Bay Transport';
  if (customer) {
    transportForm.transportId.value = customer.id;
    transportForm.transportName.value = customer.customer_name || '';
    transportForm.transportPhone.value = customer.phone || '';
    transportForm.transportPackage.value = customer.package || '';
    transportForm.transportPax.value = customer.pax || 1;
    transportForm.transportAmount.value = customer.amount || 0;
    transportForm.transportStatus.value = customer.status || 'Active';
    transportForm.transportStartDate.value = customer.start_date || '';
    transportForm.transportEndDate.value = customer.end_date || '';
    transportForm.transportNotes.value = customer.notes || '';
  } else {
    transportForm.reset();
    transportForm.transportId.value = '';
    transportForm.transportPax.value = 1;
    const pkgSelect = document.getElementById('transport-package');
    if (zone === 'vista-tiara') {
      pkgSelect.value = 'VT Transport Bulanan';
    } else if (zone === 'danga-bay') {
      pkgSelect.value = 'DB Transport Bulanan';
    } else {
      pkgSelect.value = 'Warung Bulanan';
    }
    transportForm.transportAmount.value = zone === 'warung' ? 400.00 : zone === 'danga-bay' ? 400.00 : 360.00;
  }
  transportModal.style.display = 'flex';
}

function closeTransportModal() {
  transportModal.style.display = 'none';
}

document.getElementById('transport-modal-close').addEventListener('click', closeTransportModal);
document.querySelectorAll('.transport-close-btn').forEach(btn => {
  btn.addEventListener('click', closeTransportModal);
});
transportModal.addEventListener('click', (e) => {
  if (e.target === transportModal) closeTransportModal();
});

document.getElementById('transport-package').addEventListener('change', () => {
  calcTransportAmount();
});
document.getElementById('transport-pax').addEventListener('input', () => {
  calcTransportAmount();
});

function calcTransportAmount() {
  const pkg = document.getElementById('transport-package');
  const pax = parseInt(document.getElementById('transport-pax').value) || 1;
  const baseAmount = parseFloat(pkg.selectedOptions[0].dataset.amount) || 0;
  const pkgValue = pkg.value;
  if (pkgValue.includes('Family Promo')) {
    document.getElementById('transport-amount').value = (baseAmount * pax).toFixed(2);
  } else {
    document.getElementById('transport-amount').value = baseAmount.toFixed(2);
  }
}

transportForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const data = {
    zone: currentTransportZone,
    customer_name: transportForm.transportName.value,
    phone: transportForm.transportPhone.value,
    package: transportForm.transportPackage.value,
    pax: parseInt(transportForm.transportPax.value) || 1,
    amount: parseFloat(transportForm.transportAmount.value) || 0,
    status: transportForm.transportStatus.value,
    start_date: transportForm.transportStartDate.value,
    end_date: transportForm.transportEndDate.value,
    notes: transportForm.transportNotes.value
  };
  const id = transportForm.transportId.value;
  let result;
  if (id) {
    result = await API.updateTransportCustomer(parseInt(id), data);
  } else {
    result = await API.createTransportCustomer(data);
  }
  if (result.error) { showToast('Ralat: ' + result.error); return; }
  showToast(id ? 'Pelanggan dikemas kini' : 'Pelanggan berjaya ditambah');
  closeTransportModal();
  loadTransportCustomers(currentTransportZone);
});

const btnAddVt = document.getElementById('btn-add-vt-customer');
if (btnAddVt) {
  btnAddVt.addEventListener('click', () => openTransportModal('vista-tiara'));
}
const btnAddDb = document.getElementById('btn-add-db-customer');
if (btnAddDb) {
  btnAddDb.addEventListener('click', () => openTransportModal('danga-bay'));
}
const btnAddWg = document.getElementById('btn-add-wg-customer');
if (btnAddWg) {
  btnAddWg.addEventListener('click', () => openTransportModal('warung'));
}

async function loadTransportCustomers(zone) {
  try {
    const [customers, stats, receiptStats] = await Promise.all([
      API.getTransportCustomers(zone),
      API.getTransportStats(zone),
      API.getStats(zone)
    ]);
    const prefix = zone === 'vista-tiara' ? 'vt' : zone === 'danga-bay' ? 'db' : 'wg';
    document.getElementById(`${prefix}-stat-active`).textContent = stats.active || 0;
    document.getElementById(`${prefix}-stat-pax`).textContent = stats.total_pax || 0;
    document.getElementById(`${prefix}-stat-revenue`).textContent = (receiptStats.revenue || 0).toFixed(2);
    document.getElementById(`${prefix}-stat-invoice-revenue`).textContent = (receiptStats.invoice_revenue || 0).toFixed(2);
    document.getElementById(`${prefix}-stat-terminated`).textContent = stats.terminated || 0;

    const tbody = document.getElementById(`${prefix}-customers-table`);
    tbody.innerHTML = '';
    if (!customers.length) {
      tbody.innerHTML = '<tr><td colspan="9" style="text-align:center;padding:24px;">Tiada pelanggan</td></tr>';
      return;
    }
    customers.forEach(c => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${c.customer_name || '-'}</td>
        <td>${c.phone || '-'}</td>
        <td>${c.package || '-'}</td>
        <td>${c.pax || 1}</td>
        <td>RM ${formatCurrency(c.amount)}</td>
        <td>${formatDate(c.start_date)}</td>
        <td>${formatDate(c.end_date)}</td>
        <td>${statusBadge(c.status)}</td>
        <td>
          <button class="btn btn-small btn-secondary btn-edit-transport" data-id="${c.id}">Edit</button>
          <button class="btn btn-small btn-danger btn-delete-transport" data-id="${c.id}">Padam</button>
        </td>`;
      tbody.appendChild(tr);
    });
    tbody.querySelectorAll('.btn-edit-transport').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = parseInt(btn.dataset.id);
        const customer = customers.find(c => c.id === id);
        if (customer) openTransportModal(zone, customer);
      });
    });
    tbody.querySelectorAll('.btn-delete-transport').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('Padam pelanggan ini?')) return;
        const result = await API.deleteTransportCustomer(parseInt(btn.dataset.id));
        if (result.error) { showToast('Ralat: ' + result.error); return; }
        showToast('Pelanggan dipadam');
        loadTransportCustomers(zone);
      });
    });
  } catch (e) { console.error(e); }
}

// ===== Zone-specific receipts (Vista Tiara & Danga Bay) =====
async function loadZoneReceipts(zone) {
  try {
    const receipts = await API.getReceipts({ zone });
    const prefix = zone === 'vista-tiara' ? 'vt' : zone === 'danga-bay' ? 'db' : 'wg';
    const tbody = document.getElementById(`${prefix}-recent-receipts`);
    tbody.innerHTML = '';
    const latest = receipts.slice(0, 10);
    if (!latest.length) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:24px;">Tiada invoice</td></tr>';
      return;
    }
    latest.forEach(r => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${r.receipt_number}</td>
        <td>${r.customer_name}</td>
        <td>${planBadge(r.plan)}</td>
        <td>RM ${formatCurrency(r.amount)}</td>
        <td>${statusBadge(r.status)}</td>
        <td>${formatDate(r.payment_date)}</td>`;
      tbody.appendChild(tr);
    });
  } catch (e) { console.error(e); }
}

async function loadZoneInvoices(zone) {
  try {
    const prefix = zone === 'vista-tiara' ? 'vt' : zone === 'danga-bay' ? 'db' : 'wg';
    const filters = {
      zone,
      search: document.getElementById(`${prefix}-search-input`).value,
      status: document.getElementById(`${prefix}-filter-status`).value,
      plan: document.getElementById(`${prefix}-filter-plan`).value,
      source: document.getElementById(`${prefix}-filter-source`).value,
      month: document.getElementById(`${prefix}-filter-month`)?.value || '',
      dateFrom: document.getElementById(`${prefix}-filter-date-from`).value,
      dateTo: document.getElementById(`${prefix}-filter-date-to`).value
    };
    const receipts = await API.getReceipts(filters);
    const tbody = document.getElementById(`${prefix}-invoices-table`);
    tbody.innerHTML = '';
    if (!receipts.length) {
      tbody.innerHTML = '<tr><td colspan="9" style="text-align:center;padding:24px;">Tiada invoice dijumpai</td></tr>';
      return;
    }
    receipts.forEach(r => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${r.receipt_number}</td>
        <td>${r.customer_name}</td>
        <td>${r.phone || '-'}</td>
        <td>${planBadge(r.plan)}</td>
        <td>${statusBadge(r.status)}</td>
        <td>${sourceBadge(r.source)}</td>
        <td>RM ${formatCurrency(r.amount)}</td>
        <td>${formatDate(r.payment_date)}</td>
        <td>
          <button class="btn btn-small btn-secondary btn-view" data-id="${r.id}">Lihat</button>
          <button class="btn btn-small btn-primary btn-print" data-id="${r.id}">Cetak</button>
          ${currentUser && currentUser.role === 'admin' ? `<button class="btn btn-small btn-danger btn-delete" data-id="${r.id}">Padam</button>` : ''}
        </td>`;
      tbody.appendChild(tr);
    });
    tbody.querySelectorAll('.btn-view').forEach(btn => btn.addEventListener('click', () => viewReceipt(parseInt(btn.dataset.id))));
    tbody.querySelectorAll('.btn-print').forEach(btn => btn.addEventListener('click', () => printReceipt(parseInt(btn.dataset.id))));
    tbody.querySelectorAll('.btn-delete').forEach(btn => btn.addEventListener('click', () => deleteReceipt(parseInt(btn.dataset.id))));
  } catch (e) { console.error(e); }
}

const vtBtnSearch = document.getElementById('vt-btn-search');
if (vtBtnSearch) {
  vtBtnSearch.addEventListener('click', () => loadZoneInvoices('vista-tiara'));
  document.getElementById('vt-search-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') loadZoneInvoices('vista-tiara');
  });
  document.getElementById('vt-btn-export').addEventListener('click', () => exportZoneCSV('vista-tiara'));
}

const dbBtnSearch = document.getElementById('db-btn-search');
if (dbBtnSearch) {
  dbBtnSearch.addEventListener('click', () => loadZoneInvoices('danga-bay'));
  document.getElementById('db-search-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') loadZoneInvoices('danga-bay');
  });
  document.getElementById('db-btn-export').addEventListener('click', () => exportZoneCSV('danga-bay'));
}

const wgBtnSearch = document.getElementById('wg-btn-search');
if (wgBtnSearch) {
  wgBtnSearch.addEventListener('click', () => loadZoneInvoices('warung'));
  document.getElementById('wg-search-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') loadZoneInvoices('warung');
  });
  document.getElementById('wg-btn-export').addEventListener('click', () => exportZoneCSV('warung'));
}

async function exportZoneCSV(zone) {
  const prefix = zone === 'vista-tiara' ? 'vt' : zone === 'danga-bay' ? 'db' : 'wg';
  const params = new URLSearchParams();
  params.append('zone', zone);
  const search = document.getElementById(`${prefix}-search-input`)?.value || '';
  const status = document.getElementById(`${prefix}-filter-status`)?.value || '';
  const plan = document.getElementById(`${prefix}-filter-plan`)?.value || '';
  const source = document.getElementById(`${prefix}-filter-source`)?.value || '';
  const dateFrom = document.getElementById(`${prefix}-filter-date-from`)?.value || '';
  const dateTo = document.getElementById(`${prefix}-filter-date-to`)?.value || '';
  const monthVal = document.getElementById(`${prefix}-filter-month`)?.value || '';
  if (search) params.append('search', search);
  if (status) params.append('status', status);
  if (plan) params.append('plan', plan);
  if (source) params.append('source', source);
  if (monthVal) params.append('month', monthVal);
  if (dateFrom) params.append('dateFrom', dateFrom);
  if (dateTo) params.append('dateTo', dateTo);
  const token = getToken();
  try {
    const res = await fetch(`${API_BASE_URL}/api/export/csv?${params}`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (!res.ok) {
      showToast('Ralat: gagal export CSV');
      return;
    }
    const blob = await res.blob();
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `invoice_${zone}_${new Date().toISOString().slice(0,10)}.csv`;
    a.click();
    showToast('CSV dieksport');
  } catch (e) {
    console.error('Export CSV error:', e);
    showToast('Ralat rangkaian: gagal export CSV');
  }
}

// ==================== MONTHLY ARCHIVES ====================

async function loadMonths() {
  try {
    const res = await apiFetch('/api/months');
    const months = await res.json();
    const dropdowns = ['filter-month', 'vt-filter-month', 'db-filter-month', 'wg-filter-month'];
    dropdowns.forEach(id => {
      const sel = document.getElementById(id);
      if (!sel) return;
      const current = sel.value;
      sel.innerHTML = '<option value="">Semua Bulan</option>';
      months.forEach(m => {
        const opt = document.createElement('option');
        opt.value = m.value;
        opt.textContent = m.label;
        sel.appendChild(opt);
      });
      sel.value = current;
    });
  } catch (e) { console.error('Failed to load months', e); }
}

async function loadArchives() {
  try {
    const res = await apiFetch('/api/archives');
    const archives = await res.json();
    const tbody = document.getElementById('archives-table');
    if (!tbody) return;
    tbody.innerHTML = '';
    if (!archives.length) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:24px;">Tiada arkib dijumpai</td></tr>';
      return;
    }
    const zoneLabels = { 'parking': 'AMD Parking', 'vista-tiara': 'Vista Tiara', 'danga-bay': 'Danga Bay', 'warung': 'Warung' };
    archives.forEach(a => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${a.month_label}</td>
        <td>${zoneLabels[a.zone] || a.zone}</td>
        <td>${a.receipt_count}</td>
        <td>RM ${parseFloat(a.total_revenue || 0).toFixed(2)}</td>
        <td>${a.created_at ? new Date(a.created_at).toLocaleString('ms-MY') : '-'}</td>
        <td>
          <button class="btn btn-small btn-secondary btn-archive-export" data-id="${a.id}">Export CSV</button>
          <button class="btn btn-small btn-primary btn-archive-backup" data-id="${a.id}">Download Backup</button>
          ${currentUser && currentUser.role === 'admin' ? `<button class="btn btn-small btn-danger btn-archive-delete" data-id="${a.id}">Padam</button>` : ''}
        </td>`;
      tbody.appendChild(tr);
    });
    tbody.querySelectorAll('.btn-archive-export').forEach(btn => btn.addEventListener('click', () => downloadArchiveCSV(parseInt(btn.dataset.id))));
    tbody.querySelectorAll('.btn-archive-backup').forEach(btn => btn.addEventListener('click', () => downloadArchiveBackup(parseInt(btn.dataset.id))));
    tbody.querySelectorAll('.btn-archive-delete').forEach(btn => btn.addEventListener('click', async () => {
      if (!confirm('Padam arkib ini?')) return;
      const res = await apiFetch(`/api/archives/${parseInt(btn.dataset.id)}`, { method: 'DELETE' });
      const result = await res.json();
      if (result.error) { showToast('Ralat: ' + result.error); return; }
      showToast('Arkib dipadam');
      loadArchives();
    }));
  } catch (e) { console.error('Failed to load archives', e); }
}

async function downloadArchiveCSV(id) {
  const token = getToken();
  try {
    const res = await fetch(`${API_BASE_URL}/api/archives/${id}/export`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (!res.ok) { showToast('Ralat: gagal export'); return; }
    const blob = await res.blob();
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `archive_${id}.csv`;
    a.click();
    showToast('CSV dieksport');
  } catch (e) { showToast('Ralat rangkaian'); }
}

async function downloadArchiveBackup(id) {
  const token = getToken();
  try {
    const res = await fetch(`${API_BASE_URL}/api/archives/${id}/backup`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (!res.ok) { showToast('Ralat: backup tidak tersedia. Klik "Backup ke DB" dahulu.'); return; }
    const blob = await res.blob();
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `backup_archive_${id}.zip`;
    a.click();
    showToast('Backup dimuat turun');
  } catch (e) { showToast('Ralat rangkaian'); }
}

function initArchiveControls() {
  const yearSel = document.getElementById('archive-year');
  const monthSel = document.getElementById('archive-month');
  const btnArchive = document.getElementById('btn-archive-now');
  const btnBackup = document.getElementById('btn-auto-backup');
  if (!yearSel) return;
  const now = new Date();
  for (let y = now.getFullYear(); y >= 2020; y--) {
    const opt = document.createElement('option');
    opt.value = y;
    opt.textContent = y;
    yearSel.appendChild(opt);
  }
  const prevMonth = now.getMonth() === 0 ? 12 : now.getMonth();
  const prevYear = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear();
  yearSel.value = prevYear;
  monthSel.value = prevMonth;
  btnArchive.addEventListener('click', async () => {
    if (!confirm(`Archive semua invoice untuk ${monthSel.options[monthSel.selectedIndex].text} ${yearSel.value}?`)) return;
    try {
      const res = await apiFetch('/api/archive/monthly', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ year: parseInt(yearSel.value), month: parseInt(monthSel.value) })
      });
      const result = await res.json();
      if (result.error) { showToast('Ralat: ' + result.error); return; }
      showToast(`Arkib ${result.month} berjaya dibuat`);
      loadArchives();
    } catch (e) { showToast('Ralat rangkaian'); }
  });
  btnBackup.addEventListener('click', async () => {
    if (!confirm(`Backup semua data untuk ${monthSel.options[monthSel.selectedIndex].text} ${yearSel.value} ke database?`)) return;
    try {
      const res = await apiFetch('/api/backup/auto', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ year: parseInt(yearSel.value), month: parseInt(monthSel.value) })
      });
      const result = await res.json();
      if (result.error) { showToast('Ralat: ' + result.error); return; }
      showToast(`Backup ${result.month} berjaya disimpan ke DB`);
    } catch (e) { showToast('Ralat rangkaian'); }
  });
}

initArchiveControls();
