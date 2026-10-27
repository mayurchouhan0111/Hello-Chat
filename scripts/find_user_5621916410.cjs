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

async function runQuery(token, structuredQuery) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ structuredQuery }),
  });
  return await res.json();
}

async function main() {
  const token = await refreshToken();
  const target = '5621916410';

  console.log(`Checking doc users/${target}...`);
  const docUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${target}`;
  const docRes = await fetch(docUrl, { headers: { Authorization: `Bearer ${token}` } });
  if (docRes.ok) {
    const d = await docRes.json();
    console.log('Direct doc exists:', d.name, JSON.stringify(d.fields, null, 2));
    return;
  }

  console.log('Searching via queries...');
  // Search by helloId, id, numericId, customId
  const fields = ['helloId', 'id', 'numericId', 'userId', 'customId'];
  for (const field of fields) {
    const q1 = {
      from: [{ collectionId: 'users' }],
      where: {
        fieldFilter: {
          field: { fieldPath: field },
          op: 'EQUAL',
          value: { stringValue: target }
        }
      },
      limit: 5
    };
    const res1 = await runQuery(token, q1);
    const matches1 = res1.filter(r => r.document);
    if (matches1.length > 0) {
      console.log(`Found by ${field} (string):`, matches1.map(m => ({ name: m.document.name, fields: m.document.fields })));
      return;
    }

    const q2 = {
      from: [{ collectionId: 'users' }],
      where: {
        fieldFilter: {
          field: { fieldPath: field },
          op: 'EQUAL',
          value: { integerValue: target }
        }
      },
      limit: 5
    };
    const res2 = await runQuery(token, q2);
    const matches2 = res2.filter(r => r.document);
    if (matches2.length > 0) {
      console.log(`Found by ${field} (int):`, matches2.map(m => ({ name: m.document.name, fields: m.document.fields })));
      return;
    }
  }

  console.log('Searching by list users pageSize 300 to find matching text:');
  const listUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users?pageSize=300`;
  const listRes = await fetch(listUrl, { headers: { Authorization: `Bearer ${token}` } });
  const listData = await listRes.json();
  const docs = listData.documents || [];
  console.log(`Loaded ${docs.length} users.`);
  for (const d of docs) {
    const str = JSON.stringify(d.fields);
    if (str.includes(target)) {
      console.log('Found match in user:', d.name, d.fields.username, d.fields.role, d.fields.tags, str);
    }
  }
}

main().catch(console.error);
