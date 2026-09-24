/* Trusted browser adapter. Imported files are bounded text, never code/resources. */
(function (root) {
  'use strict';
  const MAX_BYTES = 256 * 1024;
  const MAX_WORKSPACE_BYTES = 32 * 1024 * 1024;
  let busy = false;
  let unsaved = false;
  root.addEventListener('beforeunload', (event) => {
    if (!unsaved) return;
    event.preventDefault();
    // Modern browsers ignore custom text but still require returnValue.
    event.returnValue = '';
  });
  function openBounded(callback, maxBytes, accept, noun) {
      if (busy) return;
      busy = true;
      const input = root.document.createElement('input');
      input.type = 'file';
      input.accept = accept;
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
        if (file.size > maxBytes) return finish('', noun + ' exceeds ' +
          (maxBytes === MAX_BYTES ? '256 KiB.' : '32 MiB.'));
        try {
          const bytes = await file.arrayBuffer();
          if (bytes.byteLength > maxBytes) return finish('', noun + ' exceeds ' +
            (maxBytes === MAX_BYTES ? '256 KiB.' : '32 MiB.'));
          finish(new TextDecoder('utf-8', { fatal: true }).decode(bytes), '');
        } catch (_) {
          finish('', 'Could not read this ' + noun.toLowerCase() + ' as UTF-8 JSON.');
        }
      });
      root.document.body.appendChild(input);
      input.click();
  }
  function downloadBounded(text, filename, maxBytes, noun) {
      const blob = new Blob([text], { type: 'application/json;charset=utf-8' });
      if (blob.size > maxBytes) return noun + ' exceeds ' +
        (maxBytes === MAX_BYTES ? '256 KiB.' : '32 MiB.');
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
  root.SurfaceStudioFiles = Object.freeze({
    setUnsaved(value) {
      unsaved = value === true;
    },
    open(callback) {
      openBounded(callback, MAX_BYTES, '.json,application/json', 'JSON file');
    },
    openWorkspace(callback) {
      openBounded(callback, MAX_WORKSPACE_BYTES,
        '.surface-workspace.json,.json,application/json', 'Workspace recovery');
    },
    download(text, filename) {
      return downloadBounded(text, filename, MAX_BYTES, 'JSON document');
    },
    downloadWorkspace(text, filename) {
      return downloadBounded(text, filename, MAX_WORKSPACE_BYTES, 'Workspace recovery');
    }
  });
})(globalThis);
