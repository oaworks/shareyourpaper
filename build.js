#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const glob = require('glob');
const mkdirp = require('mkdirp');
const rimraf = require('rimraf');
const { execSync } = require('child_process');

const OUT = 'serve';

// Load settings (fallbacks so the build never crashes)
let settings = { site_url: '/', api: '' };
try {
  settings = JSON.parse(fs.readFileSync('settings.json','utf8'));
} catch (_) {}

// clean output
rimraf.sync(OUT);
mkdirp.sync(OUT);

// helpers
const ensureDir = f => mkdirp.sync(path.dirname(f));

// Adds base <html>, <body>, etc. 
const normaliseHtml = (html) => {
  const hasHtml = /<html[\s\S]*?>/i.test(html);
  const hasHead = /<head[\s\S]*?>/i.test(html);
  const hasBody = /<body[\s\S]*?>/i.test(html);

  if (hasHtml && hasBody) return html; // already full doc

  // If page has a <head> but no outer shell/body, wrap it
  if (hasHead) {
    const m = html.match(/<head[\s\S]*?<\/head>/i);
    const head = m ? m[0] : '<head></head>';
    const before = html.slice(0, m ? m.index : 0).trim();
    const after  = m ? html.slice(m.index + m[0].length).trim() : html;
    return [
      '<!DOCTYPE html>',
      '<html lang="en">',
      head,
      '<body>',
      before,
      after,
      '</body>',
      '</html>'
    ].join('\n');
  }

  // No <head> at all: generate a minimal doc and drop original into <body>
  let title = 'Shareyourpaper.org';
  const h1 = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
  if (h1 && h1[1]) title = h1[1].trim();

  return [
    '<!DOCTYPE html>',
    '<html lang="en">',
    '<head>',
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    `<title>${title}</title>`,
    '</head>',
    '<body>',
    html,
    '</body>',
    '</html>'
  ].join('\n');
};

const injectGlobals = (html) => {
  let doc = normaliseHtml(html);

  const hasFonts     = /fonts\.googleapis\.com/i.test(doc);
  const hasBootstrap = /\/static\/bootstrap\.min\.css/i.test(doc);
  const hasJQuery    = /jquery-1\.10\.2\.min\.js/i.test(doc);

  const pieces = [];

  // Inject Google Fonts
  if (!hasFonts) {
    pieces.push([
      '<link rel="preconnect" href="https://fonts.googleapis.com">',
      '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
      '<link href="https://fonts.googleapis.com/css?family=Roboto" rel="stylesheet">',
      '<link href="https://fonts.googleapis.com/css?family=Montserrat" rel="stylesheet">',
      '<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap" rel="stylesheet">'
    ].join('\n'));
  }

  if (!hasBootstrap) pieces.push('<link rel="stylesheet" href="/static/bootstrap.min.css">');

  // Site/API globals
  pieces.push(
    `<script>var site=${JSON.stringify(settings.site_url)};var api=${JSON.stringify(settings.api)};</script>`
  );

  if (!hasJQuery) pieces.push('<script src="/static/jquery-1.10.2.min.js"></script>');

  const tags = pieces.join('\n');

  // Insert immediately after <head>
  return doc.replace(/<head[^>]*>/i, m => `${m}\n${tags}`);
};

// Build content → serve/
glob.sync('content/**/*', { nodir: true }).forEach(src => {
  const rel = path.relative('content', src);
  const dest = path.join(OUT, rel);
  ensureDir(dest);
  if (src.endsWith('.html')) {
    const out = injectGlobals(fs.readFileSync(src, 'utf8'));
    fs.writeFileSync(dest, out);
  } else {
    fs.copyFileSync(src, dest);
  }
});

// Minify content/embed.js → serve/embed.min.js
try {
  const inFile = path.join('content', 'embed.js');
  const outFile = path.join(OUT, 'embed.min.js');
  if (fs.existsSync(inFile)) {
    mkdirp.sync(path.dirname(outFile));
    execSync(`npx terser "${inFile}" -o "${outFile}" -c -m`, { stdio: 'inherit' });
    console.log('Minified embed.js →', outFile);
  }
} catch (e) {
  console.error('Minify failed:', e.message);
}

console.log('Built content →', OUT);
