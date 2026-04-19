// ═══════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════
const state = {
  token: null,
  userId: null,
  email: null,
  role: null,
  accounts: [],
  notifications: [],
  currentTab: 'overview',
  currentTxTab: 'deposit',
};

// ═══════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════
function parseJwt(token) {
  try {
    const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(base64));
  } catch { return {}; }
}

function fmt(amount) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);
}

function humanizeError(msg) {
  // Feign errors wrap the real message: [...]: [{"message":"...","timestamp":...}]
  // Extract the inner message first
  const inner = msg.match(/\[\{"message"\s*:\s*"([^"]+)"/);
  if (inner) msg = inner[1];

  // Map known backend messages to user-friendly text
  if (/insufficient funds/i.test(msg))
    return 'Insufficient funds. Please check your balance and try again.';
  if (/account.*not.*active|not active/i.test(msg))
    return 'This account is not active.';
  if (/account.*not found|resource not found/i.test(msg))
    return 'Account not found. Please verify the account ID.';
  if (/circuit breaker|service unavailable/i.test(msg))
    return 'Service temporarily unavailable. Please try again shortly.';
  if (/401|unauthorized/i.test(msg))
    return 'Your session has expired. Please sign in again.';

  return msg;
}

function fmtDate(dateStr) {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleString('en-US', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit'
  });
}

function showToast(message, type = 'info') {
  const container = document.getElementById('toast-container');
  const icons = { success: 'fa-circle-check', error: 'fa-circle-xmark', info: 'fa-circle-info' };
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `<i class="fa-solid ${icons[type]}"></i> ${message}`;
  container.appendChild(toast);
  setTimeout(() => {
    toast.style.transition = 'opacity .3s';
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 300);
  }, 3500);
}

function setLoading(btnId, loading) {
  const btn = document.getElementById(btnId);
  if (!btn) return;
  if (loading) {
    btn._original = btn.innerHTML;
    btn.innerHTML = '<span class="spinner"></span>';
    btn.disabled = true;
  } else {
    btn.innerHTML = btn._original || btn.innerHTML;
    btn.disabled = false;
  }
}

function openModal(id)  { document.getElementById(id).classList.remove('hidden'); }
function closeModal(id) { document.getElementById(id).classList.add('hidden'); }

// ═══════════════════════════════════════════════════
// API
// ═══════════════════════════════════════════════════
const API = '/api';

async function apiFetch(path, options = {}) {
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  if (state.token) headers['Authorization'] = `Bearer ${state.token}`;
  const resp = await fetch(`${API}${path}`, { ...options, headers });
  let data = null;
  try { data = await resp.json(); } catch {}
  if (!resp.ok) {
    const msg = data?.message || data?.error || `Error: ${resp.status}`;
    throw new Error(msg);
  }
  return data;
}

// ═══════════════════════════════════════════════════
// AUTH
// ═══════════════════════════════════════════════════
async function doLogin() {
  const email = document.getElementById('login-email').value.trim();
  const pass  = document.getElementById('login-password').value;
  const errEl = document.getElementById('login-error');
  const errTx = document.getElementById('login-error-text');

  errEl.classList.add('hidden');
  if (!email || !pass) {
    errTx.textContent = 'Email and password are required.';
    errEl.classList.remove('hidden');
    return;
  }

  setLoading('btn-login', true);
  try {
    const data = await apiFetch('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password: pass })
    });
    const claims = parseJwt(data.token);
    state.token  = data.token;
    state.email  = data.email;
    state.role   = data.role;
    state.userId = claims.userId;
    localStorage.setItem('eb_token', data.token);
    localStorage.setItem('eb_email', data.email);
    localStorage.setItem('eb_role',  data.role);
    showApp();
  } catch (e) {
    errTx.textContent = e.message;
    errEl.classList.remove('hidden');
  } finally {
    setLoading('btn-login', false);
  }
}

async function doRegister() {
  const firstName = document.getElementById('reg-firstname').value.trim();
  const lastName  = document.getElementById('reg-lastname').value.trim();
  const email     = document.getElementById('reg-email').value.trim();
  const password  = document.getElementById('reg-password').value;
  const errEl     = document.getElementById('register-error');
  const errTx     = document.getElementById('register-error-text');

  errEl.classList.add('hidden');
  if (!firstName || !lastName || !email || !password) {
    errTx.textContent = 'Please fill in all fields.';
    errEl.classList.remove('hidden');
    return;
  }

  setLoading('btn-register', true);
  try {
    await apiFetch('/users/register', {
      method: 'POST',
      body: JSON.stringify({ firstName, lastName, email, password })
    });
    showToast('Account created! You can now sign in.', 'success');
    showScreen('login');
    document.getElementById('login-email').value = email;
  } catch (e) {
    errTx.textContent = e.message;
    errEl.classList.remove('hidden');
  } finally {
    setLoading('btn-register', false);
  }
}

function doLogout() {
  state.token = state.userId = state.email = state.role = null;
  state.accounts = [];
  state.notifications = [];
  localStorage.removeItem('eb_token');
  localStorage.removeItem('eb_email');
  localStorage.removeItem('eb_role');
  document.getElementById('app-container').classList.add('hidden');
  document.getElementById('auth-container').classList.remove('hidden');
  showToast('You have been signed out.', 'info');
}

// ═══════════════════════════════════════════════════
// ACCOUNTS
// ═══════════════════════════════════════════════════
async function loadAccounts() {
  try {
    state.accounts = await apiFetch('/accounts');
    renderAccounts();
    populateAccountSelects();
    updateStats();
  } catch (e) {
    showToast('Failed to load accounts: ' + e.message, 'error');
  }
}

function renderAccounts() {
  const container = document.getElementById('accounts-container');
  if (!state.accounts.length) {
    container.innerHTML = `
      <div class="empty-state">
        <i class="fa-solid fa-credit-card"></i>
        <h3>No accounts yet</h3>
        <p>Click "New Account" above to open your first account.</p>
      </div>`;
    return;
  }
  container.innerHTML = `<div class="account-cards-grid">
    ${state.accounts.map(acc => `
      <div class="account-card ${acc.accountType === 'SAVINGS' ? 'savings' : ''}">
        <div class="account-card-type">${acc.accountType === 'CHECKING' ? 'Checking Account' : 'Savings Account'}</div>
        <div class="account-card-number">${acc.accountNumber}</div>
        <div class="account-card-balance-label">Available Balance</div>
        <div class="account-card-balance">${fmt(acc.balance)}</div>
        <div class="account-card-footer">
          <div class="account-card-id">Account ID: #${acc.id}</div>
          <div class="account-card-status">${acc.status === 'ACTIVE' ? 'Active' : 'Closed'}</div>
        </div>
      </div>
    `).join('')}
  </div>`;
}

function populateAccountSelects() {
  const opts = state.accounts.map(a =>
    `<option value="${a.id}">${a.accountNumber} — ${fmt(a.balance)} (${a.accountType === 'CHECKING' ? 'Checking' : 'Savings'})</option>`
  ).join('');
  const empty = '<option value="">— No accounts —</option>';
  ['deposit-account', 'withdraw-account', 'transfer-source', 'history-account'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.innerHTML = opts || empty;
  });
}

async function createAccount() {
  const type = document.getElementById('new-account-type').value;
  setLoading('btn-create-account', true);
  try {
    await apiFetch('/accounts', { method: 'POST', body: JSON.stringify({ accountType: type }) });
    closeModal('modal-new-account');
    showToast('Account created successfully!', 'success');
    await loadAccounts();
  } catch (e) {
    showToast('Failed to create account: ' + e.message, 'error');
  } finally {
    setLoading('btn-create-account', false);
  }
}

function updateStats() {
  const total  = state.accounts.reduce((s, a) => s + parseFloat(a.balance || 0), 0);
  const active = state.accounts.filter(a => a.status === 'ACTIVE').length;
  const unread = state.notifications.filter(n => !n.read).length;
  document.getElementById('stat-total-balance').textContent = fmt(total);
  document.getElementById('stat-account-count').textContent = active;
  document.getElementById('stat-notif-count').textContent   = unread;
  const badge = document.getElementById('notif-badge');
  badge.textContent = unread;
  badge.classList.toggle('hidden', unread === 0);
}

// ═══════════════════════════════════════════════════
// TRANSACTIONS
// ═══════════════════════════════════════════════════
async function doDeposit() {
  const accountId   = document.getElementById('deposit-account').value;
  const amount      = document.getElementById('deposit-amount').value;
  const description = document.getElementById('deposit-desc').value;
  if (!accountId || !amount) { showToast('Please select an account and enter an amount.', 'error'); return; }

  setLoading('btn-deposit', true);
  try {
    await apiFetch('/transactions/deposit', {
      method: 'POST',
      body: JSON.stringify({ accountId: parseInt(accountId), amount: parseFloat(amount), description })
    });
    showToast(`${fmt(amount)} deposited successfully!`, 'success');
    document.getElementById('deposit-amount').value = '';
    document.getElementById('deposit-desc').value   = '';
    await loadAccounts();
    await loadNotifications();
    loadHistory();
  } catch (e) {
    showToast('Transaction failed: ' + humanizeError(e.message), 'error');
  } finally {
    setLoading('btn-deposit', false);
  }
}

async function doWithdraw() {
  const accountId   = document.getElementById('withdraw-account').value;
  const amount      = document.getElementById('withdraw-amount').value;
  const description = document.getElementById('withdraw-desc').value;
  if (!accountId || !amount) { showToast('Please select an account and enter an amount.', 'error'); return; }

  setLoading('btn-withdraw', true);
  try {
    await apiFetch('/transactions/withdraw', {
      method: 'POST',
      body: JSON.stringify({ accountId: parseInt(accountId), amount: parseFloat(amount), description })
    });
    showToast(`${fmt(amount)} withdrawn successfully!`, 'success');
    document.getElementById('withdraw-amount').value = '';
    document.getElementById('withdraw-desc').value   = '';
    await loadAccounts();
    await loadNotifications();
    loadHistory();
  } catch (e) {
    showToast('Transaction failed: ' + humanizeError(e.message), 'error');
  } finally {
    setLoading('btn-withdraw', false);
  }
}

async function doTransfer() {
  const sourceAccountId = document.getElementById('transfer-source').value;
  const targetAccountId = document.getElementById('transfer-target').value;
  const amount          = document.getElementById('transfer-amount').value;
  const description     = document.getElementById('transfer-desc').value;
  if (!sourceAccountId || !targetAccountId || !amount) {
    showToast('Source account, target account ID, and amount are required.', 'error');
    return;
  }

  setLoading('btn-transfer', true);
  try {
    await apiFetch('/transactions/transfer', {
      method: 'POST',
      body: JSON.stringify({
        sourceAccountId: parseInt(sourceAccountId),
        targetAccountId: parseInt(targetAccountId),
        amount: parseFloat(amount),
        description
      })
    });
    showToast(`Transfer of ${fmt(amount)} completed!`, 'success');
    document.getElementById('transfer-target').value = '';
    document.getElementById('transfer-amount').value = '';
    document.getElementById('transfer-desc').value   = '';
    await loadAccounts();
    await loadNotifications();
    loadHistory();
  } catch (e) {
    showToast('Transfer failed: ' + humanizeError(e.message), 'error');
  } finally {
    setLoading('btn-transfer', false);
  }
}

async function loadHistory() {
  const accountId = document.getElementById('history-account').value;
  if (!accountId) return;

  const container = document.getElementById('history-container');
  container.innerHTML = `<div style="padding:20px;text-align:center;color:var(--text-muted)">
    <span class="spinner" style="border-top-color:var(--accent);border-color:var(--border);"></span>
  </div>`;

  try {
    const data = await apiFetch(`/transactions/${accountId}/history`);
    if (!data || !data.length) {
      container.innerHTML = `
        <div class="empty-state" style="padding:32px;">
          <i class="fa-solid fa-clock-rotate-left"></i>
          <h3>No transactions</h3>
          <p>No transactions found for this account.</p>
        </div>`;
      return;
    }

    const typeLabel = { DEPOSIT: 'Deposit', WITHDRAWAL: 'Withdrawal', TRANSFER: 'Transfer' };
    const typeIcon  = { DEPOSIT: 'fa-arrow-down', WITHDRAWAL: 'fa-arrow-up', TRANSFER: 'fa-arrow-right-arrow-left' };

    container.innerHTML = `<div class="table-wrap"><table>
      <thead><tr>
        <th>Type</th><th>Amount</th><th>Description</th><th>Status</th><th>Accounts</th><th>Date</th>
      </tr></thead>
      <tbody>${data.map(tx => {
        const isCredit = tx.transactionType === 'DEPOSIT' ||
                         (tx.transactionType === 'TRANSFER' && String(tx.targetAccountId) === String(accountId));
        const statusMap = { SUCCESS: ['success', 'Success'], FAILED: ['danger', 'Failed'] };
        const [statusClass, statusLabel] = statusMap[tx.status] || ['muted', tx.status];
        return `<tr>
          <td><div style="display:flex;align-items:center;gap:8px;">
            <div style="width:30px;height:30px;border-radius:8px;
              background:${isCredit ? 'var(--success-light)' : 'var(--danger-light)'};
              display:flex;align-items:center;justify-content:center;">
              <i class="fa-solid ${typeIcon[tx.transactionType]}"
                 style="font-size:12px;color:${isCredit ? 'var(--success)' : 'var(--danger)'}"></i>
            </div>
            ${typeLabel[tx.transactionType] || tx.transactionType}
          </div></td>
          <td><span class="tx-amount ${isCredit ? 'credit' : 'debit'}">${isCredit ? '+' : '-'}${fmt(tx.amount)}</span></td>
          <td style="color:var(--text-muted);font-size:13px">${tx.description || '—'}</td>
          <td><span class="badge ${statusClass}">${statusLabel}</span></td>
          <td style="font-size:12px;color:var(--text-muted)">
            ${tx.sourceAccountId ? `#${tx.sourceAccountId}` : '—'} → ${tx.targetAccountId ? `#${tx.targetAccountId}` : '—'}
          </td>
          <td style="font-size:13px;color:var(--text-muted)">${fmtDate(tx.createdAt)}</td>
        </tr>`;
      }).join('')}</tbody>
    </table></div>`;
  } catch (e) {
    container.innerHTML = `
      <div class="empty-state" style="padding:32px;">
        <i class="fa-solid fa-triangle-exclamation" style="color:var(--danger)"></i>
        <h3>Failed to load</h3>
        <p>${e.message}</p>
      </div>`;
  }
}

// ═══════════════════════════════════════════════════
// NOTIFICATIONS
// ═══════════════════════════════════════════════════
async function loadNotifications() {
  try {
    state.notifications = await apiFetch('/notifications');
    renderNotifications();
    updateStats();
  } catch (e) {
    showToast('Failed to load notifications: ' + e.message, 'error');
  }
}

function renderNotifications() {
  const container  = document.getElementById('notifications-container');
  const unreadCount = state.notifications.filter(n => !n.read).length;

  document.getElementById('notif-header-subtitle').textContent =
    unreadCount > 0
      ? `You have ${unreadCount} unread notification${unreadCount > 1 ? 's' : ''}`
      : 'All caught up';

  if (!state.notifications.length) {
    container.innerHTML = `
      <div class="empty-state">
        <i class="fa-solid fa-bell-slash"></i>
        <h3>No notifications</h3>
        <p>You have no notifications at this time.</p>
      </div>`;
    return;
  }

  container.innerHTML = `<div class="notif-list">
    ${state.notifications.map(n => `
      <div class="notif-item ${n.read ? '' : 'unread'}" id="notif-${n.id}">
        <div class="notif-icon ${n.type === 'TRANSACTION' ? 'transaction' : 'system'}">
          <i class="fa-solid ${n.type === 'TRANSACTION' ? 'fa-arrow-right-arrow-left' : 'fa-circle-info'}"></i>
        </div>
        <div class="notif-body">
          <div class="notif-message">${n.message}</div>
          <div class="notif-meta">
            ${!n.read ? '<div class="notif-unread-dot"></div>' : ''}
            <div class="notif-time"><i class="fa-regular fa-clock"></i> ${fmtDate(n.createdAt)}</div>
            <span class="badge ${n.type === 'TRANSACTION' ? 'info' : 'warning'}" style="font-size:11px;">
              ${n.type === 'TRANSACTION' ? 'Transaction' : 'System'}
            </span>
          </div>
        </div>
        ${!n.read ? `
          <div class="notif-actions">
            <button class="btn btn-outline btn-sm" onclick="markAsRead(${n.id})">
              <i class="fa-solid fa-check"></i> Mark Read
            </button>
          </div>` : ''}
      </div>
    `).join('')}
  </div>`;
}

async function markAsRead(id) {
  try {
    await apiFetch(`/notifications/${id}/read`, { method: 'PATCH' });
    const notif = state.notifications.find(n => n.id === id);
    if (notif) notif.read = true;
    renderNotifications();
    updateStats();
  } catch (e) {
    showToast('Failed: ' + e.message, 'error');
  }
}

// ═══════════════════════════════════════════════════
// UI / NAVIGATION
// ═══════════════════════════════════════════════════
function showScreen(name) {
  ['login', 'register'].forEach(s =>
    document.getElementById(`screen-${s}`).classList.toggle('hidden', s !== name)
  );
}

function switchTab(name) {
  state.currentTab = name;
  document.querySelectorAll('.nav-item').forEach(el =>
    el.classList.toggle('active', el.dataset.tab === name)
  );
  ['overview', 'transactions', 'notifications'].forEach(t =>
    document.getElementById(`tab-${t}`).classList.toggle('hidden', t !== name)
  );
  if (name === 'transactions') { populateAccountSelects(); loadHistory(); }
  if (name === 'notifications') loadNotifications();
}

function switchTxTab(name) {
  state.currentTxTab = name;
  document.querySelectorAll('.tx-tab').forEach(el =>
    el.classList.toggle('active', el.dataset.tx === name)
  );
  ['deposit', 'withdraw', 'transfer'].forEach(t =>
    document.getElementById(`tx-${t}`).classList.toggle('hidden', t !== name)
  );
}

function togglePassword(inputId, iconId) {
  const input = document.getElementById(inputId);
  const icon  = document.getElementById(iconId);
  input.type  = input.type === 'password' ? 'text' : 'password';
  icon.className = `fa-solid ${input.type === 'password' ? 'fa-eye' : 'fa-eye-slash'} icon-right`;
}

function showApp() {
  document.getElementById('auth-container').classList.add('hidden');
  document.getElementById('app-container').classList.remove('hidden');

  const name = state.email.split('@')[0];
  document.getElementById('sidebar-name').textContent = name;
  document.getElementById('sidebar-role').textContent = state.role || 'USER';
  document.getElementById('sidebar-avatar').textContent = name.charAt(0).toUpperCase();

  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
  document.getElementById('overview-greeting').textContent = `${greeting}, ${name}!`;
  document.getElementById('overview-date').textContent = new Date().toLocaleDateString('en-US', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
  });

  loadAccounts();
  loadNotifications();
  setInterval(loadNotifications, 30000);
}

// ── Enter key support ──
document.getElementById('login-password').addEventListener('keydown', e => { if (e.key === 'Enter') doLogin(); });
document.getElementById('login-email').addEventListener('keydown',    e => { if (e.key === 'Enter') doLogin(); });
document.getElementById('reg-password').addEventListener('keydown',   e => { if (e.key === 'Enter') doRegister(); });

// ═══════════════════════════════════════════════════
// INIT — restore session from localStorage
// ═══════════════════════════════════════════════════
(function init() {
  const token = localStorage.getItem('eb_token');
  if (token) {
    const claims = parseJwt(token);
    const now = Math.floor(Date.now() / 1000);
    if (claims.exp && claims.exp > now) {
      state.token  = token;
      state.email  = localStorage.getItem('eb_email');
      state.role   = localStorage.getItem('eb_role');
      state.userId = claims.userId;
      showApp();
      return;
    }
    localStorage.removeItem('eb_token');
  }
})();
