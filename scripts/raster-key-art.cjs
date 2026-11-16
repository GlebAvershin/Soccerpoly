// Call after make-key-art.py. Requires @resvg/resvg-js@2.6.2.
const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { Resvg } = require('@resvg/resvg-js');

for (const kind of ['icon', 'thumb']) {
  const stem = resolve(__dirname, '../art/world-draft-' + kind);
  writeFileSync(stem + '.png', new Resvg(readFileSync(stem + '.svg')).render().asPng());
}
