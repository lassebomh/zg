// AUTO-GENERATED

type ZigType<T> = {
  readonly size: number;
  readonly align: number;
  readonly get: (view: DataView, offset: number) => T;
  readonly set: (view: DataView, offset: number, value: T) => void;
};

type FieldSet = Record<string, ZigType<any>>;
type Layout = Record<string, { offset: number; size: number }>;
type Struct<F extends FieldSet> = {
  [K in keyof F]: F[K] extends ZigType<infer T> ? T : never;
};

function alignUp(offset: number, align: number): number {
  return Math.ceil(offset / align) * align;
}

function computeLayout(fields: FieldSet): { layout: Layout; byteLength: number } {
  const layout: Layout = {};
  let offset = 0;
  let structAlign = 1;
  for (const name in fields) {
    const type = fields[name];
    offset = alignUp(offset, type.align);
    layout[name] = { offset, size: type.size };
    offset += type.size;
    structAlign = Math.max(structAlign, type.align);
  }
  return { layout, byteLength: alignUp(offset, structAlign) };
}

function createProxy<F extends FieldSet>(
  fields: F,
  layout: Layout,
  view: DataView,
): Struct<F> {
  const proxy = {} as Struct<F>;
  for (const name in fields) {
    const type = fields[name];
    const { offset } = layout[name];
    Object.defineProperty(proxy, name, {
      enumerable: true,
      get: () => type.get(view, offset),
      set: (value) => type.set(view, offset, value),
    });
  }
  return proxy;
}

const i32: ZigType<number> = {
  size: 4,
  align: 4,
  get: (view, offset) => view.getInt32(offset, true),
  set: (view, offset, value) => view.setInt32(offset, value, true),
};
const bool: ZigType<number> = {
  size: 1,
  align: 1,
  get: (view, offset) => view.getUint8(offset),
  set: (view, offset, value) => view.setUint8(offset, value),
};
const f32: ZigType<number> = {
  size: 4,
  align: 4,
  get: (view, offset) => view.getFloat32(offset, true),
  set: (view, offset, value) => view.setFloat32(offset, value, true),
};

const InputFields = {
  peer_id: i32,
  w: bool,
  a: bool,
  s: bool,
  d: bool,
  space: bool,
  shift: bool,
  mouse_x: f32,
  mouse_y: f32,
  mouse_left: bool,
  mouse_right: bool,
  screen_width: f32,
  screen_height: f32,
};

const InputComputed = computeLayout(InputFields);
export const InputLayout = InputComputed.layout;
export const InputByteLength = InputComputed.byteLength;

export function createInputProxy(view: DataView): Struct<typeof InputFields> {
  return createProxy(InputFields, InputLayout, view);
}

export type InputView = ReturnType<typeof createInputProxy>;

