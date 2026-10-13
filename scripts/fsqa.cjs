#!/usr/bin/env node
/* QA backend reader: refreshes the Firebase CLI token and runs Firestore REST queries.
   usage:
     node scripts/fsqa.cjs get rooms/abc
     node scripts/fsqa.cjs list rooms --limit 5
     node scripts/fsqa.cjs where rooms 'isActive' '==' true --limit 5
     node scripts/fsqa.cjs fields users/uid "uid,displayName"
*/
const fs = require('fs');
const os = require('os');
const path = require('path');

const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const PROJECT = 'hellochat-e8965';
const SCOPES = 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase';

function loadCfg() { return JSON.parse(fs.readFileSync(CFG, 'utf8')); }
function saveCfg(c) { fs.writeFileSync(CFG, JSON.stringify(c, null, 2)); }

async function refreshToken() {
  const cfg = loadCfg();
  if (!cfg.tokens || !cfg.tokens.refresh_token) throw new Error('no refresh token in configstore');
  const expMs = cfg.tokens.expires_at || 0;
  if (Date.now() < expMs - 60000 && cfg.tokens.access_token) return cfg.tokens.access_token;
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
  if (!r.ok) throw new Error('refresh failed: ' + r.status + ' ' + (await r.text()));
  const j = await r.json();
  cfg.tokens.access_token = j.access_token;
  cfg.tokens.expires_at = Date.now() + (j.expires_in || 3600) * 1000;
  saveCfg(cfg);
  return j.access_token;
}

async function fsCall(method, docPath, body) {
  const tok = await refreshToken();
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/${docPath}`;
  const r = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`${r.status} ${JSON.stringify(j)}`);
  return j;
}

function toJs(v) {
  if (!v) return null;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(toJs);
  if ('mapValue' in v) return fromDoc(v.mapValue.fields || {});
  if ('geoPointValue' in v) return v.geoPointValue;
  if ('bytesValue' in v) return `<bytes ${v.bytesValue.length}>`;
  if ('referenceValue' in v) return v.referenceValue;
  return v;
}
function fromDoc(fields) {
  const o = {};
  for (const [k, v] of Object.entries(fields || {})) o[k] = toJs(v);
  return o;
}

async function query(coll, opts = {}) {
  const tok = await refreshToken();
  const { where, limit = 10, orderBy, select } = opts;
  const body = {};
  if (where) body.structuredQuery = {
    from: [{ collectionId: coll }],
    where,
    orderBy,
    limit,
    ...(select ? { select: { fieldPaths: select } } : {}),
  };
  else body.structuredQuery = { from: [{ collectionId: coll }], orderBy, limit, ...(select ? { select: { fieldPaths: select } } : {}) };
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery${opts.parent ? `?parent=${encodeURIComponent(opts.parent)}` : ''}`;
  const r = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`${r.status} ${JSON.stringify(j)}`);
  const rows = [];
  for (const x of j) {
    if (x.document) rows.push({ id: x.document.name.split('/').pop(), ...fromDoc(x.document.fields) });
  }
  return rows;
}

async function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  if (!cmd) { console.log('usage: get|list|where|fields'); process.exit(1); }
  if (cmd === 'get') {
    const doc = await fsCall('GET', rest[0]);
    console.log(JSON.stringify({ id: doc.name.split('/').pop(), ...fromDoc(doc.fields) }, null, 2));
  } else if (cmd === 'list') {
    const rows = await query(rest[0], { limit: Number(rest[1]) || 10 });
    console.log(JSON.stringify(rows, null, 2));
  } else if (cmd === 'sublist') {
    // sublist <docPath> <collectionId> [limit] [orderByField] -- list a subcollection
    const [docPath, collId] = rest;
    const parent = `projects/${PROJECT}/databases/(default)/documents/${docPath}`;
    const limit = Number(rest[2]) || 50;
    const orderBy = rest[3] ? { field: { fieldPath: rest[3] }, direction: rest[4] === 'asc' ? 'ASCENDING' : 'DESCENDING' } : undefined;
    const rows = await query(collId, { parent, limit, orderBy });
    console.log(JSON.stringify(rows, null, 2));
  } else if (cmd === 'subwhere') {
    // subwhere <docPath> <collectionId> <field> <op> <val> [limit]
    const [docPath, collId, field, opIn, val] = rest;
    const parent = `projects/${PROJECT}/databases/(default)/documents/${docPath}`;
    const OPS = { '==': 'EQUAL', '!=': 'NOT_EQUAL', '<': 'LESS_THAN', '<=': 'LESS_THAN_OR_EQUAL', '>': 'GREATER_THAN', '>=': 'GREATER_THAN_OR_EQUAL', 'array-contains': 'ARRAY_CONTAINS', 'in': 'IN' };
    const op = OPS[opIn] || opIn;
    let v;
    const nv = Number(val);
    if (val === 'true') v = { booleanValue: true };
    else if (val === 'false') v = { booleanValue: false };
    else if (val === 'null') v = { nullValue: null };
    else if (!isNaN(nv) && val.trim() !== '' && String(nv) === val.trim()) v = { integerValue: val };
    else if (val.startsWith('{') || val.startsWith('[')) v = JSON.parse(val);
    else v = { stringValue: val };
    const rows = await query(collId, { parent, where: { fieldFilter: { field: { fieldPath: field }, op, value: v } }, limit: Number(rest[5]) || 50 });
    console.log(JSON.stringify(rows, null, 2));
  } else if (cmd === 'where') {
    const [coll, field, opIn, val] = rest;
    const OPS = { '==': 'EQUAL', '!=': 'NOT_EQUAL', '<': 'LESS_THAN', '<=': 'LESS_THAN_OR_EQUAL', '>': 'GREATER_THAN', '>=': 'GREATER_THAN_OR_EQUAL', 'array-contains': 'ARRAY_CONTAINS', 'in': 'IN' };
    const op = OPS[opIn] || opIn;
    let v;
    const nv = Number(val);
    if (val === 'true') v = { booleanValue: true };
    else if (val === 'false') v = { booleanValue: false };
    else if (val === 'null') v = { nullValue: null };
    else if (!isNaN(nv) && val.trim() !== '' && String(nv) === val.trim()) v = { integerValue: val };
    else if (val.startsWith('{') || val.startsWith('[')) v = JSON.parse(val);
    else v = { stringValue: val };
    const rows = await query(coll, { where: { fieldFilter: { field: { fieldPath: field }, op, value: v } }, limit: Number(rest[4]) || 10 });
    console.log(JSON.stringify(rows, null, 2));
  } else if (cmd === 'fields') {
    const doc = await fsCall('GET', rest[0]);
    const want = (rest[1] || '').split(',').map(s => s.trim()).filter(Boolean);
    const all = fromDoc(doc.fields);
    const out = want.length ? Object.fromEntries(want.map(w => [w, all[w]])) : all;
    console.log(JSON.stringify(out, null, 2));
  } else if (cmd === 'set') {
    // set <path> <json>   -- creates/merges a doc (admin REST, bypasses rules)
    const docPath = rest[0];
    let src = rest[1];
    if (src && src.startsWith('@')) src = fs.readFileSync(src.slice(1), 'utf8');
    const fields = JSON.parse(src);
    const body = { fields: {} };
    for (const [k, v] of Object.entries(fields)) body.fields[k] = toFirestore(v);
    const tok = await refreshToken();
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/${docPath}`;
    const r = await fetch(`${url}?updateMask.fieldPaths=${Object.keys(fields).map(encodeURIComponent).join('&updateMask.fieldPaths=')}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const j = await r.json();
    if (!r.ok) { console.error('ERR:', r.status, JSON.stringify(j)); process.exit(1); }
    console.log('OK ' + docPath);
  } else if (cmd === 'delete') {
    // delete <path>  -- admin REST, bypasses rules. 404 is treated as success (idempotent).
    const docPath = rest[0];
    const tok = await refreshToken();
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/${docPath}`;
    const r = await fetch(url, { method: 'DELETE', headers: { Authorization: `Bearer ${tok}` } });
    if (!r.ok && r.status !== 404) { console.error('ERR:', r.status, await r.text()); process.exit(1); }
    console.log('OK deleted ' + docPath);
  } else if (cmd === 'post') {
    // post <url> [json]  -- authenticated POST with the CLI token. For Identity
    // Toolkit (Auth) and callable-function endpoints, which Firestore REST can't reach.
    const url = rest[0];
    let src = rest[1];
    if (src && src.startsWith('@')) src = fs.readFileSync(src.slice(1), 'utf8');
    const tok = await refreshToken();
    const r = await fetch(url, {
      method: 'POST',
      headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
      body: src ? src : '{}',
    });
    const t = await r.text();
    if (!r.ok) { console.error('ERR:', r.status, t); process.exit(1); }
    console.log(t);
  } else console.log('unknown cmd', cmd);
}

function toFirestore(v) {
  if (v === null) return { nullValue: null };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'string') return /^\d{4}-\d{2}-\d{2}T/.test(v) ? { timestampValue: v } : { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFirestore) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, toFirestore(x)])) } };
}

main().catch(e => { console.error('ERR:', e.message); process.exit(1); });
