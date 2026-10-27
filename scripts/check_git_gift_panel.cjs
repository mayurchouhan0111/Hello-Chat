const { execSync } = require('child_process');
const out = execSync('git show 586a607:lib/features/rooms/presentation/widgets/gift_panel.dart', { maxBuffer: 10 * 1024 * 1024 }).toString();
const idx = out.indexOf('Widget _buildCategoryTabs');
console.log('--- FOUND Widget _buildCategoryTabs ---');
console.log(out.substring(idx, idx + 1200));
