#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const glob = require('glob');
const mkdirp = require('mkdirp');
const rimraf = require('rimraf');
const CoffeeScript = require('coffeescript');

const settings = JSON.parse(fs.readFileSync('settings.json','utf8'));
const OUT = 'serve';

// clean output
rimraf.sync(OUT);
mkdirp.sync(OUT);

// helpers
const ensureDir = f => mkdirp.sync(path.dirname(f));
const injectGlobals = (html) => {
  const hasBootstrap = /\/static\/bootstrap\.min\.css/i.test(html);
  const hasJQ       = /jquery-1\.10\.2\.min\.js/i.test(html);
  const hasNoddy    = /\/static\/noddy\.js/i.test(html) || /window\.noddy/.test(html);
  const hasInit     = /legacy-head-init\.js/i.test(html);

  const pieces = [];

  if (!hasBootstrap) {
    pieces.push('<link rel="stylesheet" href="/static/bootstrap.min.css">');
  }

  pieces.push(
    `<script>var site=${JSON.stringify(settings.site_url)};var api=${JSON.stringify(settings.api)};</script>`
  );

  if (!hasJQ) {
    pieces.push('<script src="/static/jquery-1.10.2.min.js"></script>');
  }

  pieces.push(
    fs.existsSync('static/noddy.js')
      ? '<script src="/static/noddy.js"></script>'
      : '<script>window.noddy=window.noddy||{};noddy.loggedin=noddy.loggedin||function(){return false};</script>'
  );

  if (!hasInit) {
    pieces.push('<script src="/static/legacy-head-init.js" defer></script>');
  }

  const tags = pieces.join('\n');

  // insert as the FIRST thing in <head>
  if (/<head[^>]*>/i.test(html)) return html.replace(/<head[^>]*>/i, m => `${m}\n${tags}`);
  if (/<html[^>]*>/i.test(html)) return html.replace(/<html[^>]*>/i, m => `${m}\n<head>${tags}</head>`);
  return `${tags}\n${html}`;
};

// build content → serve/
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

// compile the tiny CoffeeScript used by the site (so static copy has JS)
const coffeeIn = 'static/embed/oab_embed.coffee';
if (fs.existsSync(coffeeIn)) {
  const compiled = CoffeeScript.compile(fs.readFileSync(coffeeIn, 'utf8'), { bare: true });
  const jsOut = 'static/embed/oab_embed.js'; // compile into static, then copy step will include it
  ensureDir(jsOut);
  fs.writeFileSync(jsOut, compiled);
  console.log('Compiled:', jsOut);
}

console.log('Built content →', OUT);
