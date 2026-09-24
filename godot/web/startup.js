/* Trusted page startup only. Reports contain no imported diagram or workspace data. */
(function (root) {
  'use strict';
  const build = __STUDIO_BUILD__;
  root.SurfaceStudioStartup = Object.freeze({
    start(config) {
      const doc = root.document;
      const panel = doc.getElementById('loading');
      const status = doc.getElementById('load-status');
      const progress = doc.getElementById('load-progress');
      const report = doc.getElementById('build-report');
      const copyStatus = doc.getElementById('copy-status');
      const canvas = doc.getElementById('canvas');
      let state = 'loading';
      let message = 'Downloading Studio. The compressed engine is approximately 10 MB.';
      let timer;
      function update() {
        status.textContent = message;
        doc.getElementById('build-summary').textContent = 'Source ' + build.revision.slice(0, 12) +
          (build.dirty ? ' (local changes)' : '') + ' | Godot ' + build.engine;
        report.value = JSON.stringify({
          format: 'surface-studio-startup-report', version: 1, build,
          state, message,
          browser: String(root.navigator.userAgent || '').slice(0, 512),
          viewport: {width: root.innerWidth, height: root.innerHeight,
            pixel_ratio: root.devicePixelRatio || 1}
        }, null, 2);
      }
      function fail(error) {
        if (state === 'failed' || state === 'ready') return;
        state = 'failed';
        root.clearTimeout(timer);
        const detail = String(error && error.message || error).slice(0, 1000);
        message = 'Could not start Studio. ' + detail;
        progress.hidden = true;
        doc.getElementById('retry-startup').hidden = false;
        update();
      }
      root.SurfaceStudioLoadStatus = Object.freeze({fail});
      doc.getElementById('retry-startup').addEventListener('click', () => root.location.reload());
      doc.getElementById('copy-report').addEventListener('click', async () => {
        try {
          await root.navigator.clipboard.writeText(report.value);
          copyStatus.textContent = 'Build report copied.';
        } catch (_) {
          doc.getElementById('report-details').open = true;
          report.focus();
          report.select();
          copyStatus.textContent = 'Copy is unavailable. The report is selected for manual copying.';
        }
      });
      update();
      try {
        if (!root.Engine) throw Error('The engine script did not load. Check your connection and reload.');
        const missing = root.Engine.getMissingFeatures({threads: false});
        if (!root.WebAssembly) missing.push('WebAssembly');
        if (!root.crypto || !root.crypto.subtle) missing.push('Web Crypto (HTTPS required)');
        if (typeof root.DecompressionStream !== 'function') missing.push('gzip DecompressionStream');
        if (missing.length) throw Error('Missing browser support: ' + missing.join(', ') +
          '. Open this page over HTTPS in a browser with these features enabled.');
        root.SurfaceStudioViewport.install(doc.getElementById('studio-viewport'), canvas);
        const engine = new root.Engine(config);
        timer = root.setTimeout(() => {
          if (state !== 'loading') return;
          message = 'Startup is taking longer than expected. Check your connection; the build report below can help report the problem.';
          update();
        }, 60000);
        return Promise.resolve(engine.startGame({canvas, virtualKeyboard: true,
          onProgress(current, total) {
            if (state !== 'loading') return;
            if (Number.isFinite(current) && Number.isFinite(total) && total > 0 && current >= 0) {
              progress.max = total;
              progress.value = Math.min(current, total);
            } else {
              progress.removeAttribute('value');
            }
          }
        })).then(() => {
          if (state !== 'loading') return;
          state = 'ready';
          message = 'Studio started.';
          root.clearTimeout(timer);
          update();
          panel.hidden = true;
        }).catch(fail);
      } catch (error) {
        fail(error);
        return Promise.resolve();
      }
    }
  });
})(globalThis);
