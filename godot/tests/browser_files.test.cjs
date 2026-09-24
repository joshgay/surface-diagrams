const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../web/browser_files.js'), 'utf8');

function storageHarness() {
  const records = new Map();
  let created = false;
  const database = {
    objectStoreNames: {contains() { return created; }},
    createObjectStore() { created = true; },
    close() {},
    transaction() {
      const transaction = {};
      transaction.objectStore = () => ({
        put(value, key) {
          const request = {};
          queueMicrotask(() => { records.set(key, value); request.onsuccess(); });
          return request;
        },
        get(key) {
          const request = {};
          queueMicrotask(() => {
            request.result = records.get(key);
            request.onsuccess();
          });
          return request;
        },
        delete(key) {
          const request = {};
          queueMicrotask(() => { records.delete(key); request.onsuccess(); });
          return request;
        }
      });
      return transaction;
    }
  };
  return {
    records,
    indexedDB: {open() {
      const request = {};
      queueMicrotask(() => {
        request.result = database;
        if (!created) request.onupgradeneeded();
        request.onsuccess();
      });
      return request;
    }}
  };
}

function harness(withStorage = false) {
  const elements = [], blobs = [], revoked = [], timers = [], rootListeners = {};
  const storage = withStorage === true ? storageHarness() : withStorage || null;
  const context = {
    TextDecoder, Blob,
    addEventListener(event, callback) { rootListeners[event] = callback; },
    document: {
      body: { appendChild() {} },
      createElement(tag) {
        const listeners = {};
        const el = {tag, files: [], removed: false, clicked: false,
          addEventListener(event, cb) { listeners[event] = cb; },
          click() { this.clicked = true; }, remove() { this.removed = true; },
          fire(event) { return listeners[event](); }};
        elements.push(el);
        return el;
      }
    },
    URL: {createObjectURL(blob) { blobs.push(blob); return 'blob:test'; }, revokeObjectURL(url) { revoked.push(url); }},
    setTimeout(cb) { timers.push(cb); }
  };
  if (storage) context.indexedDB = storage.indexedDB;
  vm.runInNewContext(source, context);
  return { api: context.SurfaceStudioFiles, elements, blobs, revoked, timers,
    rootListeners, records: storage && storage.records };
}

test('unsaved edits request a close or reload warning until cleared', () => {
  const h = harness();
  function event() {
    return {prevented: false, returnValue: undefined,
      preventDefault() { this.prevented = true; }};
  }
  const clean = event();
  h.rootListeners.beforeunload(clean);
  assert.equal(clean.prevented, false);
  assert.equal(clean.returnValue, undefined);
  h.api.setUnsaved(true);
  const dirty = event();
  h.rootListeners.beforeunload(dirty);
  assert.equal(dirty.prevented, true);
  assert.equal(dirty.returnValue, '');
  h.api.setUnsaved(false);
  const saved = event();
  h.rootListeners.beforeunload(saved);
  assert.equal(saved.prevented, false);
});

test('upload forwards bounded UTF-8 text literally, not interpreted code', async () => {
  const h = harness(); let result;
  h.api.open((...args) => result = args);
  const input = h.elements[0];
  const data = Buffer.from('{"title":"<script>never run</script> ☃"}');
  input.files = [{size: data.length, arrayBuffer: async () => data}];
  await input.fire('change');
  assert.deepEqual(result, [data.toString(), '']);
  assert.equal(input.removed, true);
});
test('oversized upload is rejected before reading', async () => {
  const h = harness(); let result;
  h.api.open((...args) => result = args);
  h.elements[0].files = [{size: 262145, arrayBuffer() { throw Error('must not read'); }}];
  await h.elements[0].fire('change');
  assert.match(result[1], /256 KiB/);
});
test('workspace upload has a separate strict 32 MiB bound', async () => {
  const h = harness(); let result;
  h.api.openWorkspace((...args) => result = args);
  const input = h.elements[0];
  assert.match(input.accept, /surface-workspace/);
  input.files = [{size: 32 * 1024 * 1024 + 1,
    arrayBuffer() { throw Error('must not read'); }}];
  await input.fire('change');
  assert.match(result[1], /32 MiB/);
  assert.equal(input.removed, true);
});
test('invalid UTF-8 is rejected', async () => {
  const h = harness(); let result;
  h.api.open((...args) => result = args);
  h.elements[0].files = [{size: 1, arrayBuffer: async () => Uint8Array.from([255])}];
  await h.elements[0].fire('change');
  assert.match(result[1], /UTF-8/);
});
test('cancel releases picker and duplicate callbacks are ignored', () => {
  const h = harness(); let calls = 0;
  h.api.open(() => calls++);
  h.api.open(() => calls++);
  assert.equal(h.elements.length, 1);
  h.elements[0].fire('cancel'); h.elements[0].fire('cancel');
  assert.equal(calls, 1);
  h.api.open(() => calls++);
  assert.equal(h.elements.length, 2);
});
test('download preserves exact JSON bytes and revokes the object URL', async () => {
  const h = harness(); const json = '{"title":"α"}\n';
  assert.equal(h.api.download(json, 'draft-unvalidated.json'), '');
  assert.equal(await h.blobs[0].text(), json);
  assert.equal(h.elements[0].download, 'draft-unvalidated.json');
  assert.equal(h.elements[0].clicked, true);
  h.timers[0]();
  assert.deepEqual(h.revoked, ['blob:test']);
});
test('download enforces byte bound including multibyte text', () => {
  const h = harness();
  assert.match(h.api.download('α'.repeat(131073), 'large.json'), /256 KiB/);
  assert.equal(h.blobs.length, 0);
});
test('workspace download preserves exact recovery bytes and filename', async () => {
  const h = harness(); const recovery = '{"format":"surface-diagrams-studio-recovery"}\n';
  assert.equal(h.api.downloadWorkspace(recovery, 'draft.surface-workspace.json'), '');
  assert.equal(await h.blobs[0].text(), recovery);
  assert.equal(h.elements[0].download, 'draft.surface-workspace.json');
});
test('origin-local recovery preserves exact bytes and can be cleared', async () => {
  const h = harness(true);
  const recovery = '{"format":"surface-diagrams-studio-recovery","title":"α"}\n';
  assert.equal(await new Promise(resolve => h.api.saveLocalWorkspace(recovery, resolve)), '');
  const loaded = await new Promise(resolve =>
    h.api.loadLocalWorkspace((text, error) => resolve([text, error])));
  assert.deepEqual(loaded, [recovery, '']);
  assert.equal(await new Promise(resolve => h.api.clearLocalWorkspace(resolve)), '');
  const empty = await new Promise(resolve =>
    h.api.loadLocalWorkspace((text, error) => resolve([text, error])));
  assert.deepEqual(empty, ['', '']);
  assert.deepEqual(JSON.parse(JSON.stringify(h.records.get('current'))), {
    format: 'surface-diagrams-studio-browser-recovery-slot',
    version: 2, revision: 2, deleted: true, text: ''});
});
test('local recovery fails closed when persistent storage is unavailable or invalid', async () => {
  const unavailable = harness();
  assert.match(await new Promise(resolve =>
    unavailable.api.saveLocalWorkspace('{}', resolve)), /unavailable/);
  const h = harness(true);
  h.records.set('current', {not: 'text'});
  const invalid = await new Promise(resolve =>
    h.api.loadLocalWorkspace((text, error) => resolve([text, error])));
  assert.equal(invalid[0], '');
  assert.match(invalid[1], /invalid.*envelope/);
});
test('stale tabs cannot overwrite or clear a newer local recovery revision', async () => {
  const storage = storageHarness();
  const first = harness(storage), second = harness(storage);
  const load = api => new Promise(resolve =>
    api.loadLocalWorkspace((text, error) => resolve([text, error])));
  assert.deepEqual(await load(first.api), ['', '']);
  assert.deepEqual(await load(second.api), ['', '']);
  assert.equal(await new Promise(resolve =>
    first.api.saveLocalWorkspace('{"tab":1}', resolve)), '');
  const unopened = harness(storage);
  assert.match(await new Promise(resolve =>
    unopened.api.saveLocalWorkspace('{"unseen":true}', resolve)), /another Studio tab/);
  assert.match(await new Promise(resolve =>
    second.api.saveLocalWorkspace('{"tab":2}', resolve)), /another Studio tab/);
  assert.match(await new Promise(resolve =>
    second.api.clearLocalWorkspace(resolve)), /another Studio tab/);
  assert.deepEqual(await load(second.api), ['{"tab":1}', '']);
  assert.equal(await new Promise(resolve =>
    second.api.saveLocalWorkspace('{"tab":2}', resolve)), '');
  assert.deepEqual(await load(first.api), ['{"tab":2}', '']);
});
test('legacy text migrates once and invalid envelopes require explicit discard', async () => {
  const storage = storageHarness();
  storage.records.set('current', '{"legacy":true}');
  const h = harness(storage);
  const loaded = await new Promise(resolve =>
    h.api.loadLocalWorkspace((text, error) => resolve([text, error])));
  assert.deepEqual(loaded, ['{"legacy":true}', '']);
  assert.equal(await new Promise(resolve =>
    h.api.saveLocalWorkspace('{"migrated":true}', resolve)), '');
  assert.equal(storage.records.get('current').revision, 1);
  assert.equal(storage.records.get('current').version, 2);
  storage.records.set('current', {unexpected: true});
  assert.match(await new Promise(resolve =>
    h.api.clearLocalWorkspace(resolve)), /invalid.*envelope/);
  assert.equal(await new Promise(resolve =>
    h.api.clearLocalWorkspace(resolve, true)), '');
  assert.equal(storage.records.has('current'), false);
});

test('clear tombstones keep revisions monotone and prevent ABA overwrites', async () => {
  const storage = storageHarness();
  const first = harness(storage), second = harness(storage);
  const load = api => new Promise(resolve =>
    api.loadLocalWorkspace((text, error) => resolve([text, error])));
  const save = (api, text) => new Promise(resolve =>
    api.saveLocalWorkspace(text, resolve));
  const clear = api => new Promise(resolve => api.clearLocalWorkspace(resolve));
  assert.deepEqual(await load(first.api), ['', '']);
  assert.equal(await save(first.api, '{"generation":1}'), '');
  assert.deepEqual(await load(second.api), ['{"generation":1}', '']);
  assert.equal(await clear(second.api), '');
  assert.deepEqual(JSON.parse(JSON.stringify(storage.records.get('current'))), {
    format: 'surface-diagrams-studio-browser-recovery-slot',
    version: 2, revision: 2, deleted: true, text: ''});
  assert.equal(await save(second.api, '{"generation":3}'), '');
  assert.equal(storage.records.get('current').revision, 3);
  assert.match(await save(first.api, '{"stale":true}'), /another Studio tab/);
  assert.deepEqual(await load(first.api), ['{"generation":3}', '']);
});

test('version-one envelopes migrate and malformed tombstones fail closed', async () => {
  const storage = storageHarness();
  storage.records.set('current', {format:
    'surface-diagrams-studio-browser-recovery-slot', version: 1,
    revision: 7, text: '{"version":1}'});
  const h = harness(storage);
  const load = () => new Promise(resolve =>
    h.api.loadLocalWorkspace((text, error) => resolve([text, error])));
  assert.deepEqual(await load(), ['{"version":1}', '']);
  assert.equal(await new Promise(resolve =>
    h.api.saveLocalWorkspace('{"version":2}', resolve)), '');
  assert.deepEqual(JSON.parse(JSON.stringify(storage.records.get('current'))), {format:
    'surface-diagrams-studio-browser-recovery-slot', version: 2,
    revision: 8, deleted: false, text: '{"version":2}'});
  storage.records.set('current', {format:
    'surface-diagrams-studio-browser-recovery-slot', version: 2,
    revision: 9, deleted: true, text: '{"hidden":"data"}'});
  const invalid = await load();
  assert.equal(invalid[0], '');
  assert.match(invalid[1], /deleted slot contains workspace data/);
});
