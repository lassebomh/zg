import _init from "./generated/main.wasm?init";
import { fail } from "../lib/utils";
import type { opaque_ptr, WasmEnv, WasmFnExports } from "./generated/env";

export * from "./generated/bindings";

export interface WasmExports extends WasmFnExports {
  memory: WebAssembly.Memory;
}

export async function init(env: WasmEnv) {
  const instance = await _init({ env: env as any });
  return instance.exports as unknown as WasmExports;
}

let opaqueId = 0;
const opaqueValues = new Map<opaque_ptr, unknown>();

export const opaque = {
  get<T extends object>(ptr: opaque_ptr): T {
    const value = opaqueValues.get(ptr) ?? fail("opaque value doesn't exist");
    return value as T;
  },
  create<T extends object>(value: T): opaque_ptr {
    const ptr = ++opaqueId as unknown as opaque_ptr;
    opaqueValues.set(ptr, value);
    return ptr;
  },
  delete(ptr: opaque_ptr) {
    if (!opaqueValues.has(ptr)) fail("opaque pointer doesn't exist");
    opaqueValues.delete(ptr);
  },
};
