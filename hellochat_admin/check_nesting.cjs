const fs = require('fs');
const content = fs.readFileSync('src/screens/VIPManagement.jsx', 'utf8');
const lines = content.split('\n');

let inSingle = false, inDouble = false, inTemplate = false;
let divDepth = 0, braceDepth = 0, parenDepth = 0;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  for (let j = 0; j < line.length; j++) {
    const ch = line[j];
    const prev = j > 0 ? line[j-1] : '';
    
    // Track string literals
    if (ch === "'" && !inDouble && !inTemplate && prev !== '\\') { inSingle = !inSingle; }
    else if (ch === '"' && !inSingle && !inTemplate && prev !== '\\') { inDouble = !inDouble; }
    else if (ch === '`' && !inSingle && !inDouble && prev !== '\\') { inTemplate = !inTemplate; }
    
    if (!inSingle && !inDouble && !inTemplate) {
      if (ch === '(') parenDepth++;
      else if (ch === ')') parenDepth--;
      else if (ch === '{') braceDepth++;
      else if (ch === '}') braceDepth--;
      
      // Simple JSX div tag tracking (rough)
      if (line.substring(j).startsWith('<div ') || line.substring(j).startsWith('<div>')) {
        divDepth++;
      }
      if (line.substring(j).startsWith('</div>')) {
        divDepth--;
      }
    }
  }
  
  if (divDepth !== 0 || braceDepth !== 0 || parenDepth !== 0) {
    console.log('L' + (i+1) + ': div=' + divDepth + ' {}=' + braceDepth + ' (')=' + parenDepth);
  }
}

console.log('FINAL: div=' + divDepth + ' {}=' + braceDepth + ' ()=' + parenDepth);
