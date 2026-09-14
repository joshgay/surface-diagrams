/* Build substitutes only the SHA-256 and size of the official exported engine. */
(function (root) {
  'use strict';
  const EXPECTED_SHA256 = '__WASM_SHA256__';
  const EXPECTED_BYTES = __WASM_BYTES__;
  async function boundedBody(body, limit) {
    if (!body) throw Error('Empty engine response.');
    const reader = body.getReader();
    const chunks = []; let size = 0;
    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > limit) throw Error('Engine download exceeds its declared size.');
        chunks.push(value);
      }
    } catch (error) {
      await reader.cancel();
      throw error;
    } finally {
      reader.releaseLock();
    }
    const bytes = new Uint8Array(size); let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    return bytes;
  }
  root.SurfaceStudioLoader = Object.freeze({
    async loadWasm(url, size) {
      try {
        if (size !== EXPECTED_BYTES) throw Error('Engine manifest size mismatch.');
        const response = await root.fetch(url, { credentials: 'same-origin' });
        if (!response.ok) throw Error('Engine download failed: HTTP ' + response.status);
        const packed = await boundedBody(response.body, EXPECTED_BYTES);
        let bytes = packed;
        // Some hosts may transparently decode .gz; support both without guessing
        // content from the MIME type. The digest below still requires exact bytes.
        if (packed[0] === 0x1f && packed[1] === 0x8b) {
          if (!root.DecompressionStream) throw Error('This browser needs gzip DecompressionStream support.');
          bytes = await boundedBody(new Blob([packed]).stream().pipeThrough(new root.DecompressionStream('gzip')), EXPECTED_BYTES);
        }
        if (bytes.byteLength !== EXPECTED_BYTES) throw Error('Engine download is incomplete.');
        const digest = await root.crypto.subtle.digest('SHA-256', bytes);
        const hex = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('');
        if (hex !== EXPECTED_SHA256) throw Error('Engine checksum mismatch. Reload or report this build.');
        return new Response(bytes, { headers: { 'Content-Type': 'application/wasm' } });
      } catch (error) {
        if (root.SurfaceStudioLoadStatus) root.SurfaceStudioLoadStatus.fail(error);
        throw error;
      }
    }
  });
})(globalThis);
