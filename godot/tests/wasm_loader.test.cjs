const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const zlib = require('node:zlib');
const crypto = require('node:crypto');
// A tiny valid module plus custom-section padding so gzip is smaller than raw.
const wasm = Buffer.concat([Buffer.from([0,97,115,109,1,0,0,0,0,0xff,7,0]), Buffer.alloc(1022)]);
const template = fs.readFileSync(path.join(__dirname, '../web/wasm_loader.js'), 'utf8');
function harness(bytes = zlib.gzipSync(wasm), options = {}) {
  const failures = [];
  const context = {
    Blob, Response, Uint8Array, DecompressionStream,
    crypto: crypto.webcrypto,
    fetch: async () => new Response(bytes, {status: options.status || 200}),
    SurfaceStudioLoadStatus: { fail(error) { failures.push(error.message); } },
    ...options.context
  };
  vm.runInNewContext(template.replace('__WASM_SHA256__', crypto.createHash('sha256').update(wasm).digest('hex')).replace('__WASM_BYTES__', wasm.length), context);
  return { load: () => context.SurfaceStudioLoader.loadWasm('index.wasm.gz', options.size ?? wasm.length), failures };
}
test('compressed engine preserves exact bytes and application/wasm response', async () => {
  const response = await harness().load();
  assert.equal(response.headers.get('content-type'), 'application/wasm');
  const bytes = Buffer.from(await response.arrayBuffer());
  assert.deepEqual(bytes, wasm);
  await WebAssembly.compile(bytes);
});
test('transparent server decompression is not decoded twice', async () => {
  assert.deepEqual(Buffer.from(await (await harness(wasm).load()).arrayBuffer()), wasm);
});
test('same-size corrupted engine fails checksum and surfaces error', async () => {
  const bad = Buffer.from(wasm); bad[100] = 1;
  const h = harness(bad);
  await assert.rejects(h.load(), /checksum mismatch/);
  assert.match(h.failures[0], /checksum mismatch/);
});
test('truncated engine cannot reach instantiation', async () => {
  await assert.rejects(harness(wasm.subarray(0, 20)).load(), /incomplete/);
});
test('expansion beyond declared size is bounded', async () => {
  await assert.rejects(harness(zlib.gzipSync(Buffer.alloc(2000))).load(), /exceeds/);
});
test('wrong manifest is rejected', async () => {
  await assert.rejects(harness(undefined, {size: 3}).load(), /manifest size/);
});
test('HTTP failure and unsupported decompression have actionable errors', async () => {
  await assert.rejects(harness(undefined, {status: 403}).load(), /HTTP 403/);
  await assert.rejects(harness(undefined, {context: {DecompressionStream: undefined}}).load(), /DecompressionStream/);
});
