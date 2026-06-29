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
