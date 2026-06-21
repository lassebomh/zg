const InputsLayout = {
  peer_id: { offset: 0, size: 4 },
  w: { offset: 4, size: 1 },
  a: { offset: 5, size: 1 },
  s: { offset: 6, size: 1 },
  d: { offset: 7, size: 1 },
  space: { offset: 8, size: 1 },
  shift: { offset: 9, size: 1 },
  // 2 bytes padding here (offset 10-11) to align mouse_x to 4 bytes
  mouse_x: { offset: 12, size: 4 },
  mouse_y: { offset: 16, size: 4 },
  mouse_left: { offset: 20, size: 1 },
  mouse_right: { offset: 21, size: 1 },
  // 2 bytes padding here (offset 22-23) to align screen_x to 4 bytes
  screen_width: { offset: 24, size: 4 },
  screen_height: { offset: 28, size: 4 },
};

export function inputControl(element: HTMLElement) {
  const stop = new AbortController();
  const signal = stop.signal;

  const buffer = new ArrayBuffer(InputsLayout.screen_height.offset + InputsLayout.screen_height.size);
  const inputs = new DataView(buffer);

  inputs.setUint8(InputsLayout.screen_width.offset, element.clientWidth);
  inputs.setUint8(InputsLayout.screen_height.offset, element.clientHeight);

  const resizeObserver = new ResizeObserver((entries) => {
    for (const entry of entries) {
      const { inlineSize, blockSize } = entry.contentBoxSize[0];
      {
        inputs.setFloat32(InputsLayout.screen_width.offset, inlineSize, true);
        inputs.setFloat32(InputsLayout.screen_height.offset, blockSize, true);
      }
    }
  });

  resizeObserver.observe(element);

  element.addEventListener("contextmenu", (e) => e.preventDefault(), { signal });

  element.addEventListener(
    "pointermove",
    (e) => {
      inputs.setFloat32(InputsLayout.mouse_x.offset, e.offsetX, true);
      inputs.setFloat32(InputsLayout.mouse_y.offset, e.offsetY, true);
    },
    { signal, passive: true },
  );
  element.addEventListener(
    "pointerdown",
    (e) => {
      if (e.button === 0) {
        inputs.setUint8(InputsLayout.mouse_left.offset, 1);
      } else if (e.button === 1) {
        inputs.setUint8(InputsLayout.mouse_right.offset, 1);
      }
    },
    { signal, passive: true },
  );
  element.addEventListener(
    "pointerup",
    (e) => {
      if (e.button === 0) {
        inputs.setUint8(InputsLayout.mouse_left.offset, 0);
      } else if (e.button === 1) {
        inputs.setUint8(InputsLayout.mouse_right.offset, 0);
      }
    },
    { signal, passive: true },
  );
  window.addEventListener(
    "keydown",
    (e) => {
      if (e.repeat) return;
      let key = e.key.toLowerCase();
      if (!Number.isNaN(parseInt(key))) key = "number_" + key;
      if (key === " ") key = "space";
      if (key in InputsLayout) {
        const { offset } = InputsLayout[key as keyof typeof InputsLayout];
        inputs.setUint8(offset, 1);
      }
    },
    { signal, passive: true },
  );
  window.addEventListener(
    "keyup",
    (e) => {
      if (e.repeat) return;
      let key = e.key.toLowerCase();
      if (!Number.isNaN(parseInt(key))) key = "number_" + key;
      if (key === " ") key = "space";
      if (key in InputsLayout) {
        const { offset } = InputsLayout[key as keyof typeof InputsLayout];
        inputs.setUint8(offset, 0);
      }
    },
    { signal, passive: true },
  );

  return {
    read: (peerId: number) => {
      inputs.setInt32(InputsLayout.peer_id.offset, peerId, true);
      return buffer;
    },
    destroy: () => {
      resizeObserver.disconnect();
      stop.abort();
    },
  };
}
