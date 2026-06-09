export interface Type<T> {
  size: number;
  alignment: number;
  createView: () => BufferView<T>;
}

export interface BufferView<T> {
  bind: (buffer: ArrayBuffer, offset?: number) => void;
  /**
   * @description A view is
   */
  get: () => T;
  /**
   * @description A view is
   */
  set: (value: T) => void;
}

export type ValueOf<T extends Type<any>> = T extends Type<infer R> ? R : never;

export const f32: Type<number> = {
  alignment: 4,
  size: 4,
  createView() {
    let dataView: DataView;
    return {
      bind(buffer, offset = 0) {
        dataView = new DataView(buffer, offset);
      },
      get: () => dataView.getFloat32(0, true),
      set: (value) => dataView.setFloat32(0, value, true),
    };
  },
};

export const u32: Type<number> = {
  alignment: 4,
  size: 4,
  createView() {
    let dataView: DataView;
    return {
      bind(buffer, offset = 0) {
        dataView = new DataView(buffer, offset);
      },
      get: () => dataView.getUint32(0, true),
      set: (value) => dataView.setUint32(0, value, true),
    };
  },
};

export const i32: Type<number> = {
  alignment: 4,
  size: 4,
  createView() {
    let dataView!: DataView;
    return {
      bind(buffer, offset = 0) {
        dataView = new DataView(buffer, offset);
      },
      get: () => dataView.getInt32(0, true),
      set: (value) => dataView.setInt32(0, value, true),
    };
  },
};

export const f64: Type<number> = {
  alignment: 8,
  size: 8,
  createView() {
    let dataView: DataView;
    return {
      bind(buffer, offset = 0) {
        dataView = new DataView(buffer, offset);
      },
      get: () => dataView.getFloat64(0, true),
      set: (value) => dataView.setFloat64(0, value, true),
    };
  },
};

export const bool: Type<boolean> = {
  alignment: 1,
  size: 1,
  createView() {
    let dataView!: DataView;
    return {
      bind(buffer, offset = 0) {
        dataView = new DataView(buffer, offset);
      },
      get: () => dataView.getUint8(0) !== 0,
      set: (value) => dataView.setUint8(0, value ? 1 : 0),
    };
  },
};

export function struct<T extends { [K in string]: Type<any> }>(fields: T): Type<{ [K in keyof T]: ValueOf<T[K]> }> {
  const fieldsNames = Object.keys(fields);
  const fieldsTypes = Object.values(fields);

  const alignment = Math.max(...fieldsTypes.map((f) => f.alignment));

  const fieldOffsets: Record<(typeof fieldsNames)[number], number> = {};

  let size: number;

  {
    let offset = 0;
    for (const fieldName in fields) {
      const fieldType = fields[fieldName];
      const misalignment = offset % fieldType.alignment;
      if (misalignment !== 0) offset += fieldType.alignment - misalignment;
      fieldOffsets[fieldName] = offset;
      offset += fieldType.size;
    }
    const misalignment = offset % alignment;
    if (misalignment !== 0) offset += alignment - misalignment;
    size = offset;
  }
  return {
    alignment,
    size,
    createView() {
      let fieldViews: { [K in keyof T]: BufferView<T[K]> } = {} as any;

      for (const fieldName in fields) {
        const fieldType = fields[fieldName];
        fieldViews[fieldName] = fieldType.createView();
      }

      const obj = {} as { [K in keyof T]: ValueOf<T[K]> };

      Object.defineProperty(obj, "toJSON", {
        configurable: false,
        writable: false,
        enumerable: false,
        value: () => ({ ...obj }),
      });

      for (const fieldName in fields) {
        const fieldView = fieldViews[fieldName];

        Object.defineProperty(obj, fieldName, {
          configurable: false,
          enumerable: true,
          get: fieldView.get,
          set: fieldView.set,
        });
      }

      Object.seal(obj);

      return {
        bind(buffer, offset = 0) {
          for (const fieldName in fieldViews) {
            const fieldView = fieldViews[fieldName];
            const fieldOffset = fieldOffsets[fieldName];
            fieldView.bind(buffer, offset + fieldOffset);
          }
        },
        get: () => obj,
        set(value) {
          for (const key in fields) {
            const fieldView = fieldViews[key];
            const newValue = value[key];
            fieldView.set(newValue);
          }
        },
      };
    },
  };
}

interface FixedArray<Len extends number, T> extends Iterable<T> {
  readonly length: Len;
  [x: number]: T;
}

export function array<Len extends number, T extends Type<any>>(
  length: Len,
  type: T,
): Type<FixedArray<Len, ValueOf<T>>> {
  return {
    alignment: type.alignment,
    size: length * type.size,
    createView() {
      const elementViews: BufferView<ValueOf<T>>[] = new Array(length);

      for (let i = 0; i < length; i++) {
        elementViews[i] = type.createView();
      }

      const obj = {} as FixedArray<Len, ValueOf<T>>;

      Object.defineProperties(obj, {
        length: {
          configurable: false,
          enumerable: false,
          writable: false,
          value: length,
        },
        toJSON: {
          configurable: false,
          enumerable: false,
          writable: false,
          value: () => [...obj],
        },
        [Symbol.iterator]: {
          configurable: false,
          enumerable: false,
          writable: false,
          value: function* () {
            for (const elementView of elementViews) {
              yield elementView.get();
            }
          },
        },
      });

      for (let i = 0; i < length; i++) {
        const elementView = elementViews[i];

        Object.defineProperty(obj, i, {
          configurable: false,
          enumerable: true,
          get: elementView.get,
          set: elementView.set,
        });

        if (i > 0) {
          const negativeElementView = elementViews[length - i];
          Object.defineProperty(obj, -i, {
            configurable: false,
            enumerable: false,
            get: negativeElementView.get,
            set: negativeElementView.set,
          });
        }
      }

      Object.seal(obj);
      return {
        bind(buffer, offset = 0) {
          for (let i = 0; i < elementViews.length; i++) {
            const elementValue = elementViews[i];
            elementValue.bind(buffer, offset + type.size * i);
          }
        },
        get: () => obj,
        set: (value) => {
          for (let i = 0; i < length; i++) {
            const elementValue = elementViews[i];
            elementValue.set(value[i]);
          }
        },
      };
    },
  };
}

export function vec2(type: Type<number>) {
  return struct({
    x: type,
    y: type,
  });
}
export function vec3(type: Type<number>) {
  return struct({
    x: type,
    y: type,
    z: type,
  });
}
export function vec4(type: Type<number>) {
  return struct({
    x: type,
    y: type,
    z: type,
    w: type,
  });
}

type DiscriminatedUnion<T> = {
  [K in keyof T]: { [P in K]: T[K] } & { [P in Exclude<keyof T, K>]: undefined };
}[keyof T];
export function union<T extends { [K in string]: Type<any> }>(
  variants: T,
): Type<DiscriminatedUnion<{ [K in keyof T]: ValueOf<T[K]> }>> {
  const tagType = u32;

  const variantsNames = Object.keys(variants);
  const variantsTypes = Object.values(variants);

  const variantSize = Math.max(...variantsTypes.map((f) => f.size));
  const alignment = Math.max(tagType.alignment, ...variantsTypes.map((f) => f.alignment));

  let payloadOffset = tagType.size;
  const payloadMisalignment = payloadOffset % alignment;
  if (payloadMisalignment !== 0) payloadOffset += alignment - payloadMisalignment;

  let size = payloadOffset + variantSize;
  const trailingMisalignment = size % alignment;
  if (trailingMisalignment !== 0) size += alignment - trailingMisalignment;

  return {
    alignment,
    size,
    createView() {
      const tagView = tagType.createView();
      let variantBytes!: Uint8Array;

      let variantViews: { [K in keyof T]: BufferView<T[K]> } = {} as any;

      for (const variantName in variants) {
        const variantType = variants[variantName];
        variantViews[variantName] = variantType.createView();
      }

      const obj = {} as DiscriminatedUnion<{ [K in keyof T]: ValueOf<T[K]> }>;

      Object.defineProperty(obj, "toJSON", {
        configurable: false,
        writable: false,
        enumerable: false,
        value: () => ({ ...obj }),
      });

      for (let i = 0; i < variantsNames.length; i++) {
        const variantName = variantsNames[i];
        const variantView = variantViews[variantName];

        Object.defineProperty(obj, variantName, {
          configurable: false,
          enumerable: true,
          get: () => {
            if (tagView.get() === i) {
              return variantView.get();
            } else {
              return undefined;
            }
          },
          set: (newValue) => {
            tagView.set(i);
            variantBytes.fill(0);
            variantView.set(newValue);
          },
        });
      }

      Object.seal(obj);

      return {
        bind(buffer, offset = 0) {
          tagView.bind(buffer, offset);
          variantBytes = new Uint8Array(buffer, offset + payloadOffset, variantSize);
          for (const variantName in variantViews) {
            const variantView = variantViews[variantName];
            variantView.bind(buffer, offset + payloadOffset);
          }
        },
        get: () => obj,
        set(value) {
          variantBytes.fill(0);
          for (let i = 0; i < variantsNames.length; i++) {
            const variantName = variantsNames[i];
            const variantValue = value[variantName];
            if (variantValue === undefined) continue;
            tagView.set(i);
            const variantView = variantViews[variantName];
            variantView.set(variantValue);
          }
        },
      };
    },
  };
}
type TaggedUnion<T> = {
  [K in keyof T]: { tag: K; payload: T[K] };
}[keyof T];

export function taggedUnion<T extends { [K in string]: Type<any> }>(
  variants: T,
): Type<TaggedUnion<{ [K in keyof T]: ValueOf<T[K]> }>> {
  const tagType = u32;

  const variantsNames = Object.keys(variants);
  const variantsTypes = Object.values(variants);

  const variantSize = Math.max(...variantsTypes.map((f) => f.size));
  const alignment = Math.max(tagType.alignment, ...variantsTypes.map((f) => f.alignment));

  let payloadOffset = tagType.size;
  const payloadMisalignment = payloadOffset % alignment;
  if (payloadMisalignment !== 0) payloadOffset += alignment - payloadMisalignment;

  let size = payloadOffset + variantSize;
  const trailingMisalignment = size % alignment;
  if (trailingMisalignment !== 0) size += alignment - trailingMisalignment;

  return {
    alignment,
    size,
    createView() {
      const tagView = tagType.createView();
      let variantBytes!: Uint8Array;

      const variantViews: { [K in keyof T]: BufferView<T[K]> } = {} as any;

      for (const variantName in variants) {
        const variantType = variants[variantName];
        variantViews[variantName] = variantType.createView();
      }

      return {
        bind(buffer, offset = 0) {
          tagView.bind(buffer, offset);
          variantBytes = new Uint8Array(buffer, offset + payloadOffset, variantSize);
          for (const variantName in variantViews) {
            const variantView = variantViews[variantName];
            variantView.bind(buffer, offset + payloadOffset);
          }
        },
        get() {
          const tagIndex = tagView.get();
          const name = variantsNames[tagIndex];
          const view = variantViews[name];
          return { tag: name, payload: view.get() } as any;
        },
        set(value) {
          const tagIndex = variantsNames.indexOf(value.tag as string);
          if (tagIndex === -1) throw new Error(`Unknown variant: ${String(value.tag)}`);
          tagView.set(tagIndex);
          variantBytes.fill(0);
          variantViews[value.tag as string].set(value.payload);
        },
      };
    },
  };
}
