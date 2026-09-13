/* Controller tests with a deliberately minimal DOM double, not browser/visual
 * acceptance. No browser engine, external service, or npm dependency is used. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const assets = path.join(__dirname, '../src/surface_diagrams/editor_assets');
const html = fs.readFileSync(path.join(assets, 'index.html'), 'utf8');
const source = fs.readFileSync(path.join(assets, 'editor.js'), 'utf8');

class Element {
  constructor(tag = 'div') {
    this.tagName = tag.toUpperCase(); this.value = ''; this.checked = false;
    this.children = []; this.dataset = {}; this.style = {}; this.listeners = {};
    this.clientWidth = 1000; this.clientHeight = 800; this.files = [];
    this.classList = {add() {}, remove() {}, toggle() {}};
  }
  append(...nodes) { for (const node of nodes) { node.parent = this; this.children.push(node); } }
  replaceChildren(...nodes) { this.children = []; this.append(...nodes); }
  setAttribute(name, value) { this[name] = value; }
  addEventListener(name, handler) { this.listeners[name] = handler; }
  querySelector(selector) {
    return this.children.find(n => selector === 'svg' ? n.tagName === 'SVG' : n.class === selector.slice(1)) || null;
  }
  querySelectorAll() { return []; }
  remove() { if (this.parent) this.parent.children = this.parent.children.filter(n => n !== this); }
  click() { return this.onclick?.({}); }
}

async function setup() {
  const nodes = Object.fromEntries([...html.matchAll(/id="([^"]+)"/g)].map(m => [m[1], new Element()]));
  const toolButtons = ['select', 'arc', 'loop', 'label'].map(tool => {
    const button = new Element('button'); button.dataset.tool = tool; return button;
  });
  const style = {curve_color: '#ff00d4', curve_width: 1.5, marked_point_radius: 3,
    show_outer_ellipse: true, boundary_shape: 'dot', show_guides: false};
  const planar = {format: 'surface-diagrams', version: 1, kind: 'planar', title: 'Planar', style,
    labels: [], allow_intersections: false, curves: [], surface: {width: 400, height: 210,
      objects: [-120, -40, 40, 120].map((x, i) => ({id: 'p'+(i+1), kind: 'point', x, y: 0, radius: null}))}};
  const braid = {format: 'surface-diagrams', version: 1, kind: 'braid', title: 'Braid', style,
    labels: [], braid: {strands: 4, word: [1, -2, 3], spacing: 40, step: 48, colors: ['#ff0000'], direction: 'bottom-to-top'}};
  let nextRender = null;
  const downloads = [];
  const context = vm.createContext({
    document: {getElementById(id) { assert.ok(nodes[id], `Missing HTML control: ${id}`); return nodes[id]; },
      querySelectorAll: () => toolButtons, createElement: tag => new Element(tag),
      createElementNS: (_, tag) => new Element(tag), createTextNode: text => ({text}),
      importNode: node => node, addEventListener() {}},
    window: {addEventListener() {}}, confirm: () => true,
    DOMParser: class { parseFromString() { return {documentElement: new Element('svg'), querySelector: () => null}; } },
    Blob: class { constructor(parts) { this.parts = parts; } },
    URL: {createObjectURL(blob) { downloads.push(blob.parts.join('')); return 'blob:test'; }, revokeObjectURL() {}},
    setTimeout: () => 1, clearTimeout() {},
    fetch: async (url, options) => {
      if (url === '/api/session') return {ok: true, json: async () => ({token: 'test', examples: {planar, braid}})};
      if (url === '/api/render' && nextRender) { const callback = nextRender; nextRender = null; return callback(options); }
      const data = JSON.parse(options.body);
      if (url === '/api/validate') {
        if (data.version !== 1) return {ok: false, json: async () => ({error: 'unsupported version'})};
        return {ok: true, json: async () => data};
      }
      return {ok: true, json: async () => ({document: data, svg: '<svg/>', width: 400, height: 240,
        handles: [], cuts: [], steps: []}), text: async () => 'exported'};
    }
  });
  vm.runInContext(source, context);
  await new Promise(resolve => setImmediate(resolve));
  const run = code => vm.runInContext(code, context);
  const value = code => JSON.parse(JSON.stringify(run(code)));
  return {nodes, run, value, downloads, nextRender: callback => { nextRender = callback; }};
}

test('HTML controls exist and initial connection renders', async () => {
  const app = await setup();
  assert.equal(app.run('valid'), true);
  assert.equal(app.nodes.export.disabled, false);
  assert.equal(app.nodes['saved-state'].textContent, 'Saved');
});

test('atomic edits undo and redo, and a new edit clears redo', async () => {
  const app = await setup();
  app.run('const changed = clone(recipe); changed.title = "Revised"; commit(changed)');
  assert.equal(app.value('recipe.title'), 'Revised');
  app.nodes.undo.click(); assert.equal(app.value('recipe.title'), 'Planar');
  app.nodes.redo.click(); assert.equal(app.value('recipe.title'), 'Revised');
  app.nodes.undo.click();
  app.run('const newer = clone(recipe); newer.title = "Newer"; commit(newer)');
  assert.equal(app.run('redo.length'), 0);
  assert.equal(app.run('dirty()'), true);
});

test('history is bounded to 100 edits', async () => {
  const app = await setup();
  app.run('for (let i=0;i<105;i++) { const next=clone(recipe); next.title="Edit "+i; commit(next); }');
  assert.equal(app.run('undo.length'), 100);
});

test('cut parser preserves supplied ordering and rejects nonintegers', async () => {
  const app = await setup();
  assert.deepEqual(app.value('integers("3, 1, 4, 1")'), [3, 1, 4, 1]);
  assert.deepEqual(app.value('integers("")'), []);
  assert.throws(() => app.run('integers("1.5")'), /whole-number/);
  assert.throws(() => app.run('integers("9007199254740992")'), /whole-number/);
});

test('invalid numerical form input is not applied and restores committed value', async () => {
  const app = await setup();
  app.nodes.width.value = '';
  app.nodes.width.listeners.change();
  assert.equal(app.value('recipe.surface.width'), 400);
  assert.equal(app.nodes.width.value, 400);
  assert.match(app.nodes.error.textContent, /not applied/);
  assert.equal(app.run('valid'), true);
});

test('braid controls preserve word order and make undoable changes', async () => {
  const app = await setup();
  app.nodes['new-braid'].click();
  app.run('selectedStep = 1');
  app.nodes['invert-crossing'].click();
  assert.deepEqual(app.value('recipe.braid.word'), [1, 2, 3]);
  app.nodes['crossing-down'].click();
  assert.deepEqual(app.value('recipe.braid.word'), [1, 3, 2]);
  app.nodes['delete-crossing'].click();
  assert.deepEqual(app.value('recipe.braid.word'), [1, 3]);
  app.nodes.undo.click();
  assert.deepEqual(app.value('recipe.braid.word'), [1, 3, 2]);
});

test('stale render response cannot overwrite a newer edit', async () => {
  const app = await setup();
  let resolveRequest;
  app.nextRender(() => new Promise(resolve => { resolveRequest = resolve; }));
  const pending = app.run('render()');
  app.run('const next = clone(recipe); next.title = "Latest edit"; commit(next)');
  resolveRequest({ok: true, json: async () => ({document: {title: 'Old response'}})});
  await pending;
  assert.equal(app.value('recipe.title'), 'Latest edit');
  assert.equal(app.nodes.export.disabled, true);
});

test('save and reopen retain an editable recipe; invalid upload preserves it', async () => {
  const app = await setup();
  app.nodes.save.click();
  assert.equal(app.downloads.length, 1);
  const text = app.downloads[0];
  app.nodes['new-braid'].click();
  app.nodes.file.files = [{size: text.length, text: async () => text}];
  await app.nodes.file.onchange();
  assert.equal(app.value('recipe.kind'), 'planar');
  app.nodes.file.files = [{size: 13, text: async () => '{"version":2}'}];
  await app.nodes.file.onchange();
  assert.equal(app.value('recipe.kind'), 'planar');
  assert.match(app.nodes.error.textContent, /File not opened/);
});
