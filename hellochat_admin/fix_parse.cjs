const fs = require('fs');
let content = fs.readFileSync('src/screens/VIPManagement.jsx', 'utf8');

// Comment out the entire vip_refunds section to test
content = content.replace(
  "{category === 'vip_refunds' ? (",
  "{/* category === 'vip_refunds' ? ( */} null"
);

fs.writeFileSync('src/screens/VIPManagement.jsx', content, 'utf8');
console.log('Done - removed vip_refunds ternary branch');
