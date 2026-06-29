const fs = require('fs');
const path = require('path');

const paths = [
  path.join(process.env.APPDATA || '', 'configstore', '@firebase', 'tools.json'),
  path.join(process.env.LOCALAPPDATA || '', 'configstore', '@firebase', 'tools.json'),
  path.join(process.env.USERPROFILE || '', '.config', 'configstore', '@firebase', 'tools.json'),
  path.join(process.env.USERPROFILE || '', 'AppData', 'Local', 'configstore', '@firebase', 'tools.json'),
  path.join(process.env.USERPROFILE || '', 'AppData', 'Roaming', 'configstore', '@firebase', 'tools.json')
];

for (const p of paths) {
  if (fs.existsSync(p)) {
    console.log('FOUND:', p);
    try {
      const data = JSON.parse(fs.readFileSync(p, 'utf8'));
      console.log('TOKENS:', Object.keys(data || {}));
      console.log('USER:', data.user);
      console.log('TOKENS_VAL:', JSON.stringify(data.tokens));
    } catch (e) {
      console.error('ERROR reading:', p, e.message);
    }
  }
}
