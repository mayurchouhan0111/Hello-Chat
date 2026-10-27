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

  // Check commission_reseller_transfers
  const trfRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/commission_reseller_transfers?pageSize=50`, {
    headers: { Authorization: `Bearer ${tok}` }
  });
  if (trfRes.status === 200) {
    const td = await trfRes.json();
    const trfs = (td.documents || []).map(d => ({ id: d.name.split('/').pop(), ...fromDoc(d.fields) }));
    console.log(`commission_reseller_transfers count: ${trfs.length}`);
    for (const t of trfs) {
      console.log(`[${t.createdAt}] from=${t.senderName} (${t.senderUid}) to=${t.targetName} (${t.targetUid}) amt=$${t.transferAmountUSD}`);
    }
  }

  // Check global transactions for ADMIN_WALLET_CREDIT
  const txRes = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'transactions' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'type' },
            op: 'EQUAL',
            value: { stringValue: 'ADMIN_WALLET_CREDIT' }
          }
        }
      }
    })
  });
  const txd = await txRes.json();
  const txs = (txd || []).filter(x => x.document).map(x => fromDoc(x.document.fields));
  console.log(`ADMIN_WALLET_CREDIT count: ${txs.length}`);
  for (const t of txs) {
    console.log(`[${t.timestamp}] sender=${t.senderId} rec=${t.receiverId} amt=$${t.amount}`);
  }
}

run().catch(console.error);
