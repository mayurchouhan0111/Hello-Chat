const fs = require('fs');
let content = fs.readFileSync('firebase/firestore.rules', 'utf8');

// 1. Add FINANCIAL_FIELDS function right before PROTECTED_FIELDS
const finFunc = `    // FINANCIAL_FIELDS: Critical balances that no client SDK may ever mutate directly,
    // not even an Owner or Administrator. All mutations must go through Cloud Functions.
    function FINANCIAL_FIELDS() {
      return [
        'diamondBalance', 'diamondStock', 'beansBalance', 'walletBalance',
        'usdCommissionBalance', 'usdResellerBalance', 'totalCommissionEarned',
        'totalRechargeGenerated', 'pendingWithdrawalBalance', 'totalWithdrawnUSD'
      ];
    }\n\n`;

if (!content.includes('function FINANCIAL_FIELDS()')) {
  content = content.replace('    function PROTECTED_FIELDS()', finFunc + '    function PROTECTED_FIELDS()');
}

// 2. Update isOwner write check in match /users/{userId}
const oldWrite = `      allow write: if request.auth != null && (
        isOwner() ||`;

const newWrite = `      // Owner may write administrative profile fields, but NEVER financial balances directly from client SDK.
      // All balance mutations (walletBalance, diamondBalance, beansBalance) are strictly server-only via Cloud Functions.
      allow write: if request.auth != null && (
        (
          isOwner() &&
          !request.resource.data.diff(resource.data).affectedKeys().hasAny(FINANCIAL_FIELDS())
        ) ||`;

if (content.includes(oldWrite)) {
  content = content.replace(oldWrite, newWrite);
  fs.writeFileSync('firebase/firestore.rules', content, 'utf8');
  console.log('Successfully updated firestore.rules');
} else {
  console.log('Target string oldWrite not found in firestore.rules');
  // Check with CRLF
  const oldWriteCRLF = oldWrite.replace(/\n/g, '\r\n');
  const newWriteCRLF = newWrite.replace(/\n/g, '\r\n');
  if (content.includes(oldWriteCRLF)) {
    content = content.replace(oldWriteCRLF, newWriteCRLF);
    fs.writeFileSync('firebase/firestore.rules', content, 'utf8');
    console.log('Successfully updated firestore.rules (CRLF)');
  } else {
    console.log('Could not find write rule even with CRLF');
  }
}
