const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const build = {revision: 'a'.repeat(40), dirty: false, engine: '4.7.2', assets: {}};
const template = fs.readFileSync(path.join(__dirname, '../web/startup.js'), 'utf8');
function harness(options = {}) {
  const nodes = Object.fromEntries(['loading', 'load-status', 'load-progress', 'build-report',
    'copy-status', 'canvas', 'retry-startup', 'copy-report', 'report-details',
    'studio-viewport', 'build-summary'].map(id => [id, {
    hidden: id === 'retry-startup', textContent: '', value: '', listeners: {},
    addEventListener(name, callback) { this.listeners[name] = callback; },
    removeAttribute(name) { delete this[name]; },
    focus() { this.focused = true; }, select() { this.selected = true; }
  }]));
  let resolve, reject, startOptions, timeout, cleared = 0, starts = 0, reloads = 0, copied;
  const game = new Promise((yes, no) => {resolve = yes; reject = no;});
  class Engine {
    static getMissingFeatures() {return options.missing || [];}
    constructor() { if (options.constructorError) throw Error('Constructor failed'); }
    startGame(value) { starts++; startOptions = value; return game; }
  }
  const context = {
    Engine: options.noEngine ? undefined : Engine,
    WebAssembly: options.noWasm ? undefined : {},
    crypto: options.noCrypto ? undefined : {subtle: {}},
    DecompressionStream: options.noGzip ? undefined : function () {},
    document: {getElementById(id) {return nodes[id];}},
    navigator: {userAgent: 'test browser', clipboard: {async writeText(value) {
      if (options.clipboardDenied) throw Error('Denied'); copied = value;
    }}},
    SurfaceStudioViewport: {install() {}},
    innerWidth: 390, innerHeight: 844, devicePixelRatio: 3,
    location: {href: 'https://example.test/?private=secret', reload() {reloads++;}},
    setTimeout(callback) {timeout = callback; return 1;},
    clearTimeout() {cleared++;}
  };
  vm.runInNewContext(template.replace('__STUDIO_BUILD__', JSON.stringify({...build, dirty: !!options.dirty})), context);
  const done = context.SurfaceStudioStartup.start({});
  return {nodes, context, done, resolve, reject, game,
    report: () => JSON.parse(nodes['build-report'].value),
    progress: (...args) => startOptions.onProgress(...args),
    timeout: () => timeout(), starts: () => starts, cleared: () => cleared,
    reloads: () => reloads, copied: () => copied};
}
test('unsupported WebGL blocks engine startup and leaves actionable report', async () => {
  const h = harness({missing: ['WebGL 2']}); await h.done;
  assert.equal(h.starts(), 0);
  assert.equal(h.report().state, 'failed');
  assert.match(h.nodes['load-status'].textContent, /WebGL 2/);
  assert.equal(h.nodes.loading.hidden, false);
  assert.equal(h.nodes['retry-startup'].hidden, false);
});
test('missing engine script and synchronous engine failures stay visible', async () => {
  for (const options of [{noEngine: true}, {constructorError: true}]) {
    const h = harness(options); await h.done;
    assert.equal(h.report().state, 'failed');
    assert.equal(h.nodes['load-progress'].hidden, true);
  }
});
test('compressed engine prerequisites fail before a download starts', async () => {
  for (const [options, expected] of [[{noWasm: true}, /WebAssembly/],
    [{noCrypto: true}, /Web Crypto/], [{noGzip: true}, /DecompressionStream/]]) {
    const h = harness(options); await h.done;
    assert.equal(h.starts(), 0);
    assert.match(h.report().message, expected);
  }
});
test('successful startup reports the exact build and dismisses loading', async () => {
  const h = harness(); h.resolve(); await h.done;
  assert.equal(h.report().state, 'ready');
  assert.deepEqual(h.report().build, build);
  assert.equal(h.nodes.loading.hidden, true);
  assert.ok(h.cleared() > 0);
});
test('download progress handles unknown totals without bogus percentages', async () => {
  const h = harness();
  h.progress(40, 100); assert.equal(h.nodes['load-progress'].value, 40);
  h.progress(400, 100); assert.equal(h.nodes['load-progress'].value, 100);
  h.progress(0, 0); assert.equal(Object.hasOwn(h.nodes['load-progress'], 'value'), false);
  h.resolve(); await h.done;
});
test('slow startup warns but can still finish successfully', async () => {
  const h = harness(); h.timeout();
  assert.match(h.report().message, /longer than expected/);
  assert.equal(h.report().state, 'loading');
  h.resolve(); await h.done; assert.equal(h.report().state, 'ready');
});
test('loader failure cannot be erased by a late success or progress callback', async () => {
  const h = harness();
  h.context.SurfaceStudioLoadStatus.fail(Error('Engine checksum mismatch'));
  h.timeout(); h.progress(1, 2); h.resolve(); await h.done;
  assert.equal(h.report().state, 'failed');
  assert.match(h.report().message, /checksum mismatch/);
  assert.equal(h.nodes.loading.hidden, false);
});
test('promise rejection is reported and reload requires a user action', async () => {
  const h = harness(); h.reject(Error('HTTP 503')); await h.done;
  assert.match(h.report().message, /HTTP 503/); assert.equal(h.reloads(), 0);
  h.nodes['retry-startup'].listeners.click(); assert.equal(h.reloads(), 1);
});
test('report copy is exact and excludes page URL and diagram data', async () => {
  const h = harness({dirty: true});
  await h.nodes['copy-report'].listeners.click();
  assert.equal(h.copied(), h.nodes['build-report'].value);
  assert.equal(h.report().build.dirty, true);
  assert.match(h.nodes['build-summary'].textContent, /local changes/);
  assert.doesNotMatch(h.copied(), /private=secret|location|diagram|workspace/);
  h.resolve(); await h.done;
});
test('denied clipboard opens and selects report for manual copy', async () => {
  const h = harness({clipboardDenied: true});
  await h.nodes['copy-report'].listeners.click();
  assert.equal(h.nodes['report-details'].open, true);
  assert.equal(h.nodes['build-report'].focused, true);
  assert.equal(h.nodes['build-report'].selected, true);
  h.resolve(); await h.done;
});
