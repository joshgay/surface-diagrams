const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../web/browser_files.js'), 'utf8');

function harness() {
  const elements = [], blobs = [], revoked = [], timers = [], rootListeners = {};
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
  vm.runInNewContext(source, context);
  return { api: context.SurfaceStudioFiles, elements, blobs, revoked, timers, rootListeners };
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
