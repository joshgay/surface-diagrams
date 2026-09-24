/* Keep the exported canvas inside the current mobile visual viewport. */
(function (root) {
  'use strict';
  const MAX_SIZE = 16384;
  let host = null;
  let canvas = null;
  let installed = false;
  let current = Object.freeze({width: 1, height: 1, viewportWidth: 1, viewportHeight: 1, offsetLeft: 0, offsetTop: 0});

  function bounded(value) {
    const number = Number(value);
    if (!Number.isFinite(number) || number <= 0) return 0;
    return Math.min(MAX_SIZE, Math.max(1, Math.floor(number)));
  }

  function measure() {
    const visual = root.visualViewport;
    const documentElement = root.document && root.document.documentElement;
    const width = bounded(visual && visual.width) || bounded(root.innerWidth) || bounded(documentElement && documentElement.clientWidth) || 1;
    const height = bounded(visual && visual.height) || bounded(root.innerHeight) || bounded(documentElement && documentElement.clientHeight) || 1;
    const offsetLeft = Math.max(0, bounded(visual && visual.offsetLeft));
    const offsetTop = Math.max(0, bounded(visual && visual.offsetTop));
    return {width, height, offsetLeft, offsetTop};
  }

  function sync() {
    const viewport = measure();
    if (host && host.style) {
      host.style.setProperty('--studio-left', viewport.offsetLeft + 'px');
      host.style.setProperty('--studio-top', viewport.offsetTop + 'px');
      host.style.setProperty('--studio-width', viewport.width + 'px');
      host.style.setProperty('--studio-height', viewport.height + 'px');
    }
    // The canvas content box excludes CSS safe-area padding on its host. Godot
    // should lay out in those usable CSS pixels, not physical backing pixels.
    const width = bounded(canvas && canvas.clientWidth) || viewport.width;
    const height = bounded(canvas && canvas.clientHeight) || viewport.height;
    current = Object.freeze({
      width, height,
      viewportWidth: viewport.width, viewportHeight: viewport.height,
      offsetLeft: viewport.offsetLeft, offsetTop: viewport.offsetTop
    });
    return current;
  }

  function install(hostElement, canvasElement) {
    if (!hostElement || !canvasElement) throw Error('Studio viewport host and canvas are required.');
    host = hostElement;
    canvas = canvasElement;
    if (!installed) {
      installed = true;
      if (root.addEventListener) {
        root.addEventListener('resize', sync);
        root.addEventListener('orientationchange', sync);
      }
      if (root.visualViewport && root.visualViewport.addEventListener) {
        root.visualViewport.addEventListener('resize', sync);
        root.visualViewport.addEventListener('scroll', sync);
      }
    }
    return sync();
  }

  root.SurfaceStudioViewport = Object.freeze({MAX_SIZE, install, read: sync});
})(globalThis);
