#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const glob = require('glob');
const mkdirp = require('mkdirp');
const rimraf = require('rimraf');

const OUT = 'serve';
const SRC = 'static';
const DEST = path.join(OUT, 'static');

const copy = (src, dest) => { mkdirp.sync(path.dirname(dest)); fs.copyFileSync(src, dest); };

rimraf.sync(DEST);
mkdirp.sync(DEST);

glob.sync(`${SRC}/**/*`, { nodir: true }).forEach(src => {
  const rel = path.relative(SRC, src);
  copy(src, path.join(DEST, rel));
});

if (fs.existsSync('_redirects')) copy('_redirects', path.join(OUT, '_redirects'));

console.log('Copied static →', DEST);
