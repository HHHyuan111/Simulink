const fs = require('fs');
const path = require('path');
const sharp = require('C:/Users/lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
sharp(fs.readFileSync(path.join(__dirname, 'compensation_flow.svg')))
  .png().toFile(path.join(__dirname, 'compensation_flow.png'));
