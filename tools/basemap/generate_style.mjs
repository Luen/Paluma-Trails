// Generates content/basemap/style.json from the Protomaps basemaps package.
//
// The style is written with two placeholders that the app replaces at runtime:
//   PALUMA_PMTILES  -> the PMTiles archive (file:// on native, https on web)
//   PALUMA_ASSETS   -> the directory holding fonts/ and sprites/
//
// Usage: node tools/basemap/generate_style.mjs <output.json>
import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);
const basemaps = require('@protomaps/basemaps');

const outArg = process.argv[2];
if (!outArg) {
  console.error('usage: generate_style.mjs <output.json>');
  process.exit(64);
}

// Resolves userPath under the working directory, stripping `..` segments so a
// crafted CLI argument cannot escape (CWE-23 / Snyk javascript/PT). Absolute
// paths are accepted only when they already sit under cwd, then rewritten as a
// join of cwd + sanitised relative segments.
function resolveOutputPath(userPath) {
  const root = path.resolve(process.cwd());
  let relativeInput = userPath;
  if (path.isAbsolute(userPath)) {
    const abs = path.resolve(userPath);
    const rel = path.relative(root, abs);
    if (rel.startsWith('..') || path.isAbsolute(rel)) {
      console.error(
        `refusing to write outside the working directory: ${userPath}`,
      );
      process.exit(64);
    }
    relativeInput = rel;
  }
  // Snyk-recognised sanitisation: drop leading parent-directory segments.
  const safeSuffix = path
    .normalize(relativeInput)
    .replace(/^(\.\.(\/|\\|$))+/g, '');
  return path.join(root, safeSuffix);
}

const out = resolveOutputPath(outArg);

const layers = basemaps.layers('basemap', basemaps.namedFlavor('light'), {
  lang: 'en',
});

// MapLibre resolves a `text-font` stack to a directory name, and the Protomaps
// default names contain spaces. Spaces in a Flutter web asset path get
// percent-encoded twice (the build writes `Noto%20Sans%20Regular/` on disk), so
// the glyph requests would 404. Rename the stacks, and keep the on-disk
// directories (see build_basemap.sh) in step.
const fontNames = {
  'Noto Sans Regular': 'Noto-Sans-Regular',
  'Noto Sans Medium': 'Noto-Sans-Medium',
  'Noto Sans Italic': 'Noto-Sans-Italic',
};

function renameFonts(value) {
  if (Array.isArray(value)) return value.map(renameFonts);
  if (typeof value === 'string') return fontNames[value] ?? value;
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [key, renameFonts(entry)]),
    );
  }
  return value;
}

for (const layer of layers) {
  const textFont = layer.layout?.['text-font'];
  if (textFont !== undefined) layer.layout['text-font'] = renameFonts(textFont);
}

const style = {
  version: 8,
  name: 'Paluma Trails basemap (light)',
  metadata: {
    'paluma:note':
      'Generated from @protomaps/basemaps. PALUMA_PMTILES and PALUMA_ASSETS are replaced at runtime by the app.',
    'paluma:attribution':
      'Map data © OpenStreetMap contributors (ODbL). Tiles by Protomaps (ISC).',
  },
  sources: {
    basemap: { type: 'vector', url: 'pmtiles://PALUMA_PMTILES' },
  },
  glyphs: 'PALUMA_ASSETS/fonts/{fontstack}/{range}.pbf',
  sprite: 'PALUMA_ASSETS/sprites/light',
  layers,
};

writeFileSync(out, `${JSON.stringify(style, null, 1)}\n`);
console.log(`wrote ${out} (${layers.length} layers)`);
