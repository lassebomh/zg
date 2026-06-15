export enum Input {
  w,
  a,
  s,
  d,
  space,
  shift,
  mouse_x,
  mouse_y,
  mouse_left,
  mouse_right,
  screen_width,
  screen_height,
  __length__,
}

export function inputControl(element: HTMLElement, inputs: Float32Array) {
  const stop = new AbortController();

  inputs[Input.screen_width] = element.clientWidth;
  inputs[Input.screen_height] = element.clientHeight;

  const resizeObserver = new ResizeObserver((entries) => {
    for (const entry of entries) {
      const { inlineSize, blockSize } = entry.contentBoxSize[0];
      inputs[Input.screen_width] = inlineSize;
      inputs[Input.screen_height] = blockSize;
    }
  });

  resizeObserver.observe(element);

  element.addEventListener(
    "pointermove",
    (e) => {
      inputs[Input.mouse_x] = e.offsetX;
      inputs[Input.mouse_y] = e.offsetY;
    },
    { signal: stop.signal, passive: true },
  );

  element.addEventListener(
    "pointerdown",
    (e) => {
      if (e.button === 0) {
        inputs[Input.mouse_left] = 1;
      } else if (e.button === 1) {
        inputs[Input.mouse_right] = 1;
      }
    },
    { signal: stop.signal, passive: true },
  );
  element.addEventListener(
    "pointerup",
    (e) => {
      if (e.button === 0) {
        inputs[Input.mouse_left] = 0;
      } else if (e.button === 1) {
        inputs[Input.mouse_right] = 0;
      }
    },
    { signal: stop.signal, passive: true },
  );
  window.addEventListener(
    "keydown",
    (e) => {
      if (e.repeat) return;
      let key = e.key.toLowerCase();
      if (!Number.isNaN(parseInt(key))) key = "number_" + key;
      if (key === " ") key = "space";
      if (key in Input) {
        // @ts-ignore
        const index: number = Input[key];
        inputs[index] = 1;
      }
    },
    { signal: stop.signal, passive: true },
  );
  window.addEventListener(
    "keyup",
    (e) => {
      if (e.repeat) return;
      let key = e.key.toLowerCase();
      if (!Number.isNaN(parseInt(key))) key = "number_" + key;
      if (key === " ") key = "space";
      if (key in Input) {
        // @ts-ignore
        const index: number = Input[key];
        inputs[index] = 0;
      }
    },
    { signal: stop.signal, passive: true },
  );

  return {
    read: () => {
      return new Float32Array(inputs);
    },
    stop: () => {
      resizeObserver.disconnect();
      stop.abort();
    },
  };
}
