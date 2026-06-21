// clanker generated
const InputLayout = {
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

export const InputByteLength = InputLayout.screen_height.offset + InputLayout.screen_height.size;

export function createInputProxy(view: DataView) {
  return {
    get peer_id() {
      return view.getInt32(InputLayout.peer_id.offset, true);
    },
    set peer_id(newValue) {
      view.setInt32(InputLayout.peer_id.offset, newValue, true);
    },
    get w() {
      return view.getUint8(InputLayout.w.offset);
    },
    set w(newValue) {
      view.setUint8(InputLayout.w.offset, newValue);
    },
    get a() {
      return view.getUint8(InputLayout.a.offset);
    },
    set a(newValue) {
      view.setUint8(InputLayout.a.offset, newValue);
    },
    get s() {
      return view.getUint8(InputLayout.s.offset);
    },
    set s(newValue) {
      view.setUint8(InputLayout.s.offset, newValue);
    },
    get d() {
      return view.getUint8(InputLayout.d.offset);
    },
    set d(newValue) {
      view.setUint8(InputLayout.d.offset, newValue);
    },
    get space() {
      return view.getUint8(InputLayout.space.offset);
    },
    set space(newValue) {
      view.setUint8(InputLayout.space.offset, newValue);
    },
    get shift() {
      return view.getUint8(InputLayout.shift.offset);
    },
    set shift(newValue) {
      view.setUint8(InputLayout.shift.offset, newValue);
    },
    get mouse_x() {
      return view.getFloat32(InputLayout.mouse_x.offset, true);
    },
    set mouse_x(newValue) {
      view.setFloat32(InputLayout.mouse_x.offset, newValue, true);
    },
    get mouse_y() {
      return view.getFloat32(InputLayout.mouse_y.offset, true);
    },
    set mouse_y(newValue) {
      view.setFloat32(InputLayout.mouse_y.offset, newValue, true);
    },
    get mouse_left() {
      return view.getUint8(InputLayout.mouse_left.offset);
    },
    set mouse_left(newValue) {
      view.setUint8(InputLayout.mouse_left.offset, newValue);
    },
    get mouse_right() {
      return view.getUint8(InputLayout.mouse_right.offset);
    },
    set mouse_right(newValue) {
      view.setUint8(InputLayout.mouse_right.offset, newValue);
    },
    get screen_width() {
      return view.getFloat32(InputLayout.screen_width.offset, true);
    },
    set screen_width(newValue) {
      view.setFloat32(InputLayout.screen_width.offset, newValue, true);
    },
    get screen_height() {
      return view.getFloat32(InputLayout.screen_height.offset, true);
    },
    set screen_height(newValue) {
      view.setFloat32(InputLayout.screen_height.offset, newValue, true);
    },
  };
}

export type InputView = ReturnType<typeof createInputProxy>;

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
