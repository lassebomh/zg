import {
  createInputProxy,
  InputByteLength,
  InputLayout,
  type InputView,
} from "./generated/bindings";

// The struct layout and DataView proxy are generated from the Zig `Input`
// struct (src/js/inputs.zig) by `zig build` into src/generated/. This module
// only adds the hand-written DOM event wiring on top of those bindings.
export { createInputProxy, InputByteLength, InputLayout };
export type { InputView };

export function inputControl(element: HTMLElement, inputs: InputView) {
  const stop = new AbortController();
  const signal = stop.signal;

  inputs.screen_width = element.clientWidth;
  inputs.screen_height = element.clientHeight;

  const resizeObserver = new ResizeObserver((entries) => {
    for (const entry of entries) {
      const { inlineSize, blockSize } = entry.contentBoxSize[0];
      {
        inputs.screen_width = inlineSize;
        inputs.screen_height = blockSize;
      }
    }
  });

  resizeObserver.observe(element);

  element.addEventListener("contextmenu", (e) => e.preventDefault(), { signal });

  element.addEventListener(
    "pointermove",
    (e) => {
      inputs.mouse_x = e.offsetX;
      inputs.mouse_y = e.offsetY;
    },
    { signal, passive: true },
  );
  element.addEventListener(
    "pointerdown",
    (e) => {
      if (e.button === 0) {
        inputs.mouse_left = 1;
      } else if (e.button === 1) {
        inputs.mouse_right = 1;
      }
    },
    { signal, passive: true },
  );
  element.addEventListener(
    "pointerup",
    (e) => {
      if (e.button === 0) {
        inputs.mouse_left = 0;
      } else if (e.button === 1) {
        inputs.mouse_right = 0;
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
      if (key in inputs) {
        inputs[key as keyof typeof inputs] = 1;
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
      if (key in inputs) {
        inputs[key as keyof typeof inputs] = 0;
      }
    },
    { signal, passive: true },
  );

  return {
    destroy: () => {
      resizeObserver.disconnect();
      stop.abort();
    },
  };
}
