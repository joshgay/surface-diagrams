/* Trusted browser adapter. Imported files are bounded text, never code/resources. */
(function (root) {
  'use strict';
  const MAX_BYTES = 256 * 1024;
  let busy = false;
  let unsaved = false;
  root.addEventListener('beforeunload', (event) => {
    if (!unsaved) return;
    event.preventDefault();
    // Modern browsers ignore custom text but still require returnValue.
    event.returnValue = '';
  });
  root.SurfaceStudioFiles = Object.freeze({
    setUnsaved(value) {
      unsaved = value === true;
    },
    open(callback) {
      if (busy) return;
      busy = true;
      const input = root.document.createElement('input');
      input.type = 'file';
      input.accept = '.json,application/json';
      input.hidden = true;
      let finished = false;
      function finish(text, error) {
        if (finished) return;
        finished = true;
        busy = false;
        input.remove();
        callback(text, error);
      }
      input.addEventListener('cancel', () => finish('', ''));
      input.addEventListener('change', async () => {
        const file = input.files[0];
        if (!file) return finish('', '');
        if (file.size > MAX_BYTES) return finish('', 'JSON file exceeds 256 KiB.');
        try {
          const bytes = await file.arrayBuffer();
          if (bytes.byteLength > MAX_BYTES) return finish('', 'JSON file exceeds 256 KiB.');
          finish(new TextDecoder('utf-8', { fatal: true }).decode(bytes), '');
        } catch (_) {
          finish('', 'Could not read this file as UTF-8 JSON.');
        }
      });
      root.document.body.appendChild(input);
      input.click();
    },
    download(text, filename) {
      const blob = new Blob([text], { type: 'application/json;charset=utf-8' });
      if (blob.size > MAX_BYTES) return 'JSON document exceeds 256 KiB.';
      const url = root.URL.createObjectURL(blob);
      const link = root.document.createElement('a');
      link.href = url;
      link.download = filename;
      root.document.body.appendChild(link);
      link.click();
      link.remove();
      root.setTimeout(() => root.URL.revokeObjectURL(url), 1000);
      return '';
    }
  });
})(globalThis);
