/**
 * generate_icons.cjs
 * 
 * Genera los PNGs del launcher de Android a partir del SVG
 * en todas las densidades mipmap requeridas.
 * 
 * Uso: cd /tmp/icon-gen && node /path/to/scripts/generate_icons.cjs
 */

const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const PROJECT_DIR = path.resolve(__dirname, '..');
const SVG_PATH = path.join(PROJECT_DIR, 'assets', 'ic_launcher.svg');
const MIPMAP_BASE = path.join(
  PROJECT_DIR, 'flutter_app', 'android', 'app', 'src', 'main', 'res'
);
const ASSETS_DIR = path.join(PROJECT_DIR, 'assets');

const DENSITIES = [
  { dir: 'mipmap-mdpi', size: 48 },
  { dir: 'mipmap-hdpi', size: 72 },
  { dir: 'mipmap-xhdpi', size: 96 },
  { dir: 'mipmap-xxhdpi', size: 144 },
  { dir: 'mipmap-xxxhdpi', size: 192 },
];

const BG_COLOR = '#0F1B2D';
const SVG_CONTENT = fs.readFileSync(SVG_PATH, 'utf-8');

function wrapSvg(svg, size) {
  const scale = size / 120;
  let inner = svg.replace(/<\?xml[^>]*\?>/g, '').trim();
  inner = inner.replace(/<svg[^>]*>/g, '').replace(/<\/svg>/g, '').trim();
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
    <rect width="${size}" height="${size}" fill="${BG_COLOR}"/>
    <g transform="scale(${scale})">
      ${inner}
    </g>
  </svg>`);
}

async function generate() {
  for (const d of DENSITIES) {
    const outDir = path.join(MIPMAP_BASE, d.dir);
    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
    const outPath = path.join(outDir, 'ic_launcher.png');
    await sharp(wrapSvg(SVG_CONTENT, d.size)).png().toFile(outPath);
    const kb = (fs.statSync(outPath).size / 1024).toFixed(1);
    console.log(`✓ ${d.dir}/ic_launcher.png (${d.size}x${d.size}) — ${kb} KB`);
  }

  const webSize = 512;
  const assetsPng = path.join(ASSETS_DIR, 'ic_launcher.png');
  await sharp(wrapSvg(SVG_CONTENT, webSize)).png().toFile(assetsPng);
  const kb = (fs.statSync(assetsPng).size / 1024).toFixed(1);
  console.log(`✓ assets/ic_launcher.png (${webSize}x${webSize}) — ${kb} KB`);

  console.log('\n✅ Todos los iconos generados exitosamente.');
}

generate().catch(err => { console.error('Error:', err); process.exit(1); });
