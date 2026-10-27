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

async function main() {
  const token = await refreshToken();
  const uid = 'pc6mVRnBCVOTV9nM5J7FErJ5WZc2';
  const docUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${uid}`;

  console.log(`Fetching user ${uid}...`);
  const getRes = await fetch(docUrl, { headers: { Authorization: `Bearer ${token}` } });
  if (!getRes.ok) {
    throw new Error(`Failed to get user: ${getRes.status} ${await getRes.text()}`);
  }
  const userDoc = await getRes.json();
  const currentFields = userDoc.fields || {};
  console.log('Current user state:');
  console.log('DisplayName:', currentFields.displayName?.stringValue);
  console.log('HelloId:', currentFields.helloId?.integerValue || currentFields.helloId?.stringValue);
  console.log('Role:', currentFields.role?.stringValue);
  console.log('Tags:', currentFields.tags?.arrayValue?.values?.map(v => v.stringValue));
  console.log('BranchId:', currentFields.branchId?.stringValue);

  // Preserve existing tags and add 'Admin'
  const existingTags = (currentFields.tags?.arrayValue?.values || []).map(v => v.stringValue).filter(Boolean);
  const newTags = Array.from(new Set([...existingTags, 'Admin']));

  // Patch document with role=admin, tags, branchId
  const patchUrl = `${docUrl}?updateMask.fieldPaths=role&updateMask.fieldPaths=tags&updateMask.fieldPaths=branchId`;
  const patchBody = {
    fields: {
      role: { stringValue: 'admin' },
      branchId: { stringValue: 'branch-prod-1' },
      tags: {
        arrayValue: {
          values: newTags.map(t => ({ stringValue: t }))
        }
      }
    }
  };

  console.log('Updating user to Admin...');
  const patchRes = await fetch(patchUrl, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(patchBody)
  });

  if (!patchRes.ok) {
    throw new Error(`Failed to patch user: ${patchRes.status} ${await patchRes.text()}`);
  }

  const updatedDoc = await patchRes.json();
  console.log('Successfully updated user:');
  console.log('Updated Role:', updatedDoc.fields.role?.stringValue);
  console.log('Updated BranchId:', updatedDoc.fields.branchId?.stringValue);
  console.log('Updated Tags:', updatedDoc.fields.tags?.arrayValue?.values?.map(v => v.stringValue));
  console.log('Admin Panel enabled for ID 5621916410!');
}

main().catch(console.error);
