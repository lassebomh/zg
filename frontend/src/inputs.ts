const InputsLayout = {
  id: { offset: 0, size: 4 },
  w: { offset: 4, size: 1 },
  a: { offset: 5, size: 1 },
  s: { offset: 6, size: 1 },
  d: { offset: 7, size: 1 },
  space: { offset: 8, size: 1 },
  shift: { offset: 9, size: 1 },
  // 2 bytes padding here (offset 10-11) to align f32
  mouse: { offset: 12, size: 8 }, // 2x f32
  mouse_left: { offset: 20, size: 1 },
  mouse_right: { offset: 21, size: 1 },
  // 2 bytes padding here (offset 22-23) to align f32
  screen: { offset: 24, size: 8 }, // 2x f32
} as const;

// export const localId = Math.abs(crypto.getRandomValues(new Int32Array(1))[0]);

// console.log(localId);

export function inputControl(element: HTMLElement) {
  const stop = new AbortController();
  const signal = stop.signal;

  const buffer = new ArrayBuffer(InputsLayout.screen.offset + InputsLayout.screen.size);
  const inputs = new DataView(buffer);

  inputs.setUint8(InputsLayout.screen.offset, element.clientWidth);
  inputs.setUint8(InputsLayout.screen.offset + InputsLayout.screen.size / 2, element.clientHeight);

  const resizeObserver = new ResizeObserver((entries) => {
    for (const entry of entries) {
      const { inlineSize, blockSize } = entry.contentBoxSize[0];
      {
        inputs.setFloat32(InputsLayout.screen.offset, inlineSize, true);
        inputs.setFloat32(InputsLayout.screen.offset + InputsLayout.screen.size / 2, blockSize, true);
      }
    }
  });

  resizeObserver.observe(element);

  element.addEventListener("contextmenu", (e) => e.preventDefault(), { signal });

  element.addEventListener(
    "pointermove",
    (e) => {
      inputs.setFloat32(InputsLayout.mouse.offset, e.offsetX, true);
      inputs.setFloat32(InputsLayout.mouse.offset + InputsLayout.mouse.size / 2, e.offsetY, true);
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
      inputs.setInt32(InputsLayout.id.offset, peerId, true);
      return buffer;
    },
    destroy: () => {
      resizeObserver.disconnect();
      stop.abort();
    },
  };
}
