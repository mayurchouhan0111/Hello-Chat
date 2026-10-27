const fs = require('fs');
const os = require('os');
const path = require('path');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';

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
  const tok = await refreshToken();

  // Find all users with walletBalance > 0
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
        usersWithWallet.push({ uid, ...u });
      }
    }
    pageToken = uData.nextPageToken;
  } while (pageToken);

  console.log(`Auditing ${usersWithWallet.length} users with walletBalance > 0...\n`);

  for (const u of usersWithWallet) {
    const txRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${u.uid}/transactions?pageSize=100`, {
      headers: { Authorization: `Bearer ${tok}` }
    });
    let txs = [];
    if (txRes.status === 200) {
      const td = await txRes.json();
      txs = (td.documents || []).map(d => ({ id: d.name.split('/').pop(), ...fromDoc(d.fields) }));
    }

    const salaryRewards = txs.filter(t => t.type === 'salary_reward' || t.category === 'wallet');
    const purchases = txs.filter(t => t.type === 'purchase' && t.description && t.description.includes('Paid $'));
    const otherTxs = txs.filter(t => t.type !== 'salary_reward' && !(t.type === 'purchase' && t.description && t.description.includes('Paid $')));

    const totalSalaryCredited = salaryRewards.reduce((sum, t) => sum + (Number(t.amount) || 0), 0);
    const purchasesSpent = purchases.map(t => {
      const m = t.description.match(/Paid \$([0-9.]+)/);
      return m ? parseFloat(m[1]) : 0;
    }).reduce((sum, val) => sum + val, 0);

    console.log(`[${u.uid}] HelloID: ${u.helloId || u.userId} | Name: "${u.displayName || u.name}"`);
    console.log(`  Current walletBalance: $${u.walletBalance}`);
    console.log(`  Salary reward txs: count=${salaryRewards.length}, sum=$${totalSalaryCredited}`);
    console.log(`  Wallet diamond purchases: count=${purchases.length}, sumSpent=$${purchasesSpent}`);
    console.log(`  Difference: (sum - spent) = $${totalSalaryCredited - purchasesSpent}`);
    console.log(`  Other non-wallet txs count: ${otherTxs.length}`);
    console.log('---------------------------------------------------------');
  }
}

run().catch(console.error);
