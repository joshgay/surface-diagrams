/* Trusted browser adapter. Imported files are bounded text, never code/resources. */
(function (root) {
  'use strict';
  const MAX_BYTES = 256 * 1024;
  const MAX_WORKSPACE_BYTES = 32 * 1024 * 1024;
  const DATABASE_NAME = 'surface-diagrams-studio';
  const DATABASE_VERSION = 1;
  const RECOVERY_STORE = 'workspace-recovery';
  const RECOVERY_KEY = 'current';
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
  function once(callback) {
    let called = false;
    return (...args) => {
      if (called) return;
      called = true;
      callback(...args);
    };
  }
  function openRecoveryStore(mode, callback, operation) {
    let finished = false;
    const finish = (...args) => {
      if (finished) return;
      finished = true;
      callback(...args);
    };
    if (!root.indexedDB) {
      finish(null, 'Persistent browser storage is unavailable.');
      return;
    }
    let request;
    try {
      request = root.indexedDB.open(DATABASE_NAME, DATABASE_VERSION);
    } catch (_) {
      finish(null, 'Could not open persistent browser storage.');
      return;
    }
    request.onupgradeneeded = () => {
      const database = request.result;
      try {
        if (!database.objectStoreNames.contains(RECOVERY_STORE)) {
          database.createObjectStore(RECOVERY_STORE);
        }
      } catch (_) {
        request.transaction.abort();
      }
    };
    request.onerror = () => finish(null,
      'Could not open persistent browser storage.');
    request.onblocked = () => finish(null,
      'Persistent browser storage is blocked by another Studio tab.');
    request.onsuccess = () => {
      const database = request.result;
      if (finished) {
        database.close();
        return;
      }
      let transaction;
      try {
        transaction = database.transaction(RECOVERY_STORE, mode);
      } catch (_) {
        database.close();
        finish(null, 'Could not access persistent browser storage.');
        return;
      }
      const close = once((value, error) => {
        database.close();
        finish(value, error);
      });
      transaction.onabort = () => close(null,
        'Persistent browser storage rejected the workspace update.');
      transaction.onerror = () => close(null,
        'Persistent browser storage failed while updating the workspace.');
      operation(transaction.objectStore(RECOVERY_STORE), close);
    };
  }
  function workspaceBytes(text) {
    return new Blob([text], { type: 'application/json;charset=utf-8' }).size;
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
    },
    saveLocalWorkspace(text, callback) {
      if (workspaceBytes(text) > MAX_WORKSPACE_BYTES) {
        callback('Workspace recovery exceeds 32 MiB.');
        return;
      }
      openRecoveryStore('readwrite', (value, error) => callback(error || ''),
        (store, finish) => {
          const request = store.put(text, RECOVERY_KEY);
          request.onerror = () => finish(null,
            'Could not save the local browser recovery.');
          request.onsuccess = () => finish(null, '');
        });
    },
    loadLocalWorkspace(callback) {
      openRecoveryStore('readonly', (value, error) =>
        callback(typeof value === 'string' ? value : '', error || ''),
        (store, finish) => {
          const request = store.get(RECOVERY_KEY);
          request.onerror = () => finish(null,
            'Could not read the local browser recovery.');
          request.onsuccess = () => {
            const value = request.result;
            if (value === undefined) return finish('', '');
            if (typeof value !== 'string') return finish(null,
              'The local browser recovery has an invalid type.');
            if (workspaceBytes(value) > MAX_WORKSPACE_BYTES) return finish(null,
              'The local browser recovery exceeds 32 MiB.');
            finish(value, '');
          };
        });
    },
    clearLocalWorkspace(callback) {
      openRecoveryStore('readwrite', (value, error) => callback(error || ''),
        (store, finish) => {
          const request = store.delete(RECOVERY_KEY);
          request.onerror = () => finish(null,
            'Could not clear the local browser recovery.');
          request.onsuccess = () => finish(null, '');
        });
    }
  });
})(globalThis);
