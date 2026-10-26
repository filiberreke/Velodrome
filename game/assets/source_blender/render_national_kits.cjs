// npm install sharp, or set NODE_PATH to the bundled dependency node_modules.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

async function main() {
  const source = path.join(__dirname, 'national_kits');
  const destination = path.join(__dirname, '..', 'riders', 'national_kits');
  for (const country of await fs.readdir(source)) {
    if (!(await fs.stat(path.join(source, country))).isDirectory()) continue;
    for (const asset of ['skinsuit', 'helmet']) {
      await sharp(path.join(source, country, asset + '.svg'))
        .png({ compressionLevel: 9 })
        .toFile(path.join(destination, country, asset + '.png'));
      console.log(`${country}/${asset}.png`);
    }
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
