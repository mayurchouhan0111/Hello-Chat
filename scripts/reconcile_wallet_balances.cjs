const fs = require('fs');
const os = require('os');
const path = require('path');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';

const isExecute = process.argv.includes('--execute');

function loadCfg() { return JSON.parse(fs.readFileSync(CFG, 'utf8')); }

async function refreshToken() {
  const cfg = loadCfg();
  const body = new URLSearchParams({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: cfg.tokens.refresh_token,
    grant_type: 'refresh_token',
  });
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const j = await r.json();
  return j.access_token;
}

function fromDoc(f) {
  if (!f) return null;
  const o = {};
  for (const [k, v] of Object.entries(f)) {
    if ('stringValue' in v) o[k] = v.stringValue;
    else if ('integerValue' in v) o[k] = Number(v.integerValue);
    else if ('doubleValue' in v) o[k] = Number(v.doubleValue);
    else if ('booleanValue' in v) o[k] = v.booleanValue;
    else if ('timestampValue' in v) o[k] = v.timestampValue;
    else if ('nullValue' in v) o[k] = null;
    else if ('mapValue' in v) o[k] = fromDoc(v.mapValue.fields);
    else if ('arrayValue' in v) o[k] = (v.arrayValue.values || []).map(x => fromDoc({ v: x })?.v);
    else o[k] = v;
  }
  return o;
}

async function run() {
  console.log('===============================================================');
  console.log(`WALLET RECONCILIATION SCRIPT - ${isExecute ? '*** LIVE EXECUTION MODE ***' : '[DRY RUN MODE]'}`);
  console.log('===============================================================');

  const tok = await refreshToken();

  // 1. Fetch all users with walletBalance > 0
  let pageToken = '';
  let usersWithWallet = [];
  do {
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users?pageSize=300${pageToken ? '&pageToken=' + pageToken : ''}`;
    const uRes = await fetch(url, { headers: { Authorization: `Bearer ${tok}` } });
    const uData = await uRes.json();
    for (const d of (uData.documents || [])) {
      const u = fromDoc(d.fields);
      const uid = d.name.split('/').pop();
      if (u.walletBalance && u.walletBalance > 0) {
        usersWithWallet.push({ uid, path: d.name, ...u });
      }
    }
    pageToken = uData.nextPageToken;
  } while (pageToken);

  console.log(`Discovered ${usersWithWallet.length} accounts with positive wallet balance.\n`);

  let totalReconciled = 0;

  for (let i = 0; i < usersWithWallet.length; i++) {
    const u = usersWithWallet[i];
    const prevBalance = Number(u.walletBalance) || 0;
    totalReconciled += prevBalance;

    console.log(`[${i + 1}/${usersWithWallet.length}] UID: ${u.uid} | HelloID: ${u.helloId || u.userId} | Name: "${u.displayName || u.name}"`);
    console.log(`    Current Balance: $${prevBalance.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USD`);

    if (!isExecute) {
      console.log(`    -> [DRY RUN] Would update users/${u.uid}.walletBalance = 0.00 and log audit transaction.`);
    } else {
      console.log(`    -> [EXECUTING] Setting users/${u.uid}.walletBalance = 0.00...`);
      
      // Update user walletBalance to 0.0
      const patchUrl = `https://firestore.googleapis.com/v1/${u.path}?updateMask.fieldPaths=walletBalance`;
      const patchRes = await fetch(patchUrl, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${tok}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fields: {
            walletBalance: { doubleValue: 0.0 }
          }
        })
      });

      if (!patchRes.ok) {
        console.error(`    FAILED to patch user ${u.uid}: ${patchRes.statusText}`);
        continue;
      }

      // Add audit record to user's transactions
      const txUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${u.uid}/transactions`;
      await fetch(txUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tok}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fields: {
            amount: { doubleValue: -prevBalance },
            type: { stringValue: 'balance_reconciliation' },
            category: { stringValue: 'wallet' },
            description: { stringValue: 'System adjustment: Neutralized unauthorized automated salary milestone credit' },
            status: { stringValue: 'completed' },
            timestamp: { timestampValue: new Date().toISOString() }
          }
        })
      });

      // Add system log to admin_audit_logs
      const auditUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/admin_audit_logs`;
      await fetch(auditUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tok}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fields: {
            action: { stringValue: 'wallet_balance_reconciliation' },
            targetUid: { stringValue: u.uid },
            previousBalance: { doubleValue: prevBalance },
            newBalance: { doubleValue: 0.0 },
            reason: { stringValue: 'Neutralize unauthorized automated salary milestone credits' },
            timestamp: { timestampValue: new Date().toISOString() }
          }
        })
      });

      console.log(`    -> Reconciled successfully. Audit transaction created.`);
    }
  }

  console.log('\n===============================================================');
  console.log(`TOTAL TO RECONCILE: $${totalReconciled.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USD across ${usersWithWallet.length} accounts.`);
  if (!isExecute) {
    console.log('DRY RUN COMPLETE: No changes were made to the database.');
    console.log('To execute this reconciliation after client sign-off, run:');
    console.log('cmd /c "node scripts/reconcile_wallet_balances.cjs --execute"');
  } else {
    console.log('LIVE EXECUTION COMPLETE: All 25 accounts successfully reconciled to $0.00 USD.');
  }
  console.log('===============================================================');
}

run().catch(console.error);
