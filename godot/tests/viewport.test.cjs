const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../web/viewport.js'), 'utf8');
const shell = fs.readFileSync(path.join(__dirname, '../web/shell.html'), 'utf8');

function eventTarget(fields = {}) {
  const listeners = new Map();
  return {
    ...fields,
    addEventListener(name, callback) {
      if (!listeners.has(name)) listeners.set(name, []);
      listeners.get(name).push(callback);
    },
    fire(name) { for (const callback of listeners.get(name) || []) callback(); },
    count(name) { return (listeners.get(name) || []).length; }
  };
}

function harness(options = {}) {
  const styles = {};
  const host = {style: {setProperty(name, value) { styles[name] = value; }}};
  const canvas = {clientWidth: options.canvasWidth || 0, clientHeight: options.canvasHeight || 0};
  const visualViewport = options.visualViewport === null ? undefined : eventTarget({
    width: 390, height: 844, offsetLeft: 0, offsetTop: 0, ...options.visualViewport
  });
  const context = eventTarget({
    innerWidth: options.innerWidth || 1280,
    innerHeight: options.innerHeight || 800,
    visualViewport,
    document: {documentElement: {clientWidth: 1024, clientHeight: 768}}
  });
  vm.runInNewContext(source, context);
  return {api: context.SurfaceStudioViewport, context, visualViewport, host, canvas, styles};
}

test('visual viewport positions the host while canvas content excludes safe areas', () => {
  const h = harness({canvasWidth: 366, canvasHeight: 810, visualViewport: {offsetLeft: 2.9, offsetTop: 7.8}});
  assert.deepEqual({...h.api.install(h.host, h.canvas)}, {
    width: 366, height: 810, viewportWidth: 390, viewportHeight: 844, offsetLeft: 2, offsetTop: 7
  });
  assert.deepEqual(h.styles, {
    '--studio-left': '2px', '--studio-top': '7px', '--studio-width': '390px', '--studio-height': '844px'
  });
});

test('visual viewport resize and scroll update keyboard and browser-chrome geometry', () => {
  const h = harness({canvasWidth: 390, canvasHeight: 844});
  h.api.install(h.host, h.canvas);
  h.visualViewport.width = 844; h.visualViewport.height = 390;
  h.visualViewport.offsetTop = 12; h.canvas.clientWidth = 820; h.canvas.clientHeight = 356;
  h.visualViewport.fire('resize');
  assert.equal(h.api.read().width, 820);
  assert.equal(h.api.read().height, 356);
  assert.equal(h.styles['--studio-height'], '390px');
  h.visualViewport.offsetTop = 18; h.visualViewport.fire('scroll');
  assert.equal(h.styles['--studio-top'], '18px');
});

test('installation is idempotent and fallback dimensions are bounded', () => {
  const h = harness({visualViewport: null, innerWidth: 20000, innerHeight: 390});
  h.api.install(h.host, h.canvas);
  h.api.install(h.host, h.canvas);
  assert.deepEqual({...h.api.read()}, {
    width: 16384, height: 390, viewportWidth: 16384, viewportHeight: 390, offsetLeft: 0, offsetTop: 0
  });
  assert.equal(h.context.count('resize'), 1);
  assert.equal(h.context.count('orientationchange'), 1);
  assert.throws(() => h.api.install(null, h.canvas), /required/);
});

test('shell declares dynamic viewport, safe areas, and the trusted adapter', () => {
  assert.match(shell, /viewport-fit=cover/);
  assert.match(shell, /interactive-widget=resizes-content/);
  assert.match(shell, /env\(safe-area-inset-(top|left),/);
  assert.match(shell, /id="studio-viewport"/);
  assert.match(shell, /SurfaceStudioViewport\.install/);
});
