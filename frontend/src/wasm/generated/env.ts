// AUTO-GENERATED

export type opaque_ptr = { readonly _: unique symbol};

export interface WasmFnExports {
  /**
   * @returns *js.inputs.Input
   */
  jsGetInputBufferPtr(): number;
  /**
   * @param peer_id i32
   * @returns usize
   */
  jsGetPeerInputsLen(peer_id: number): number;
  /**
   * @param peer_id i32
   * @returns [*]js.inputs.Input
   */
  jsGetPeerInputsPtr(peer_id: number): number;
  /**
   * @param itick i32
   * @returns void
   */
  jsPullInputBuffer(itick: number): void;
  /**
   * @param itick i32
   * @param alpha f32
   * @param screen_width i32
   * @param screen_height i32
   * @param peer_id i32
   * @returns void
   */
  jsRenderTick(itick: number, alpha: number, screen_width: number, screen_height: number, peer_id: number): void;
}

export interface WasmEnv {
  /**
   * @param commandsTypesPtr *[commandsCap]CommandType
   * @param commandsArgsPtr *[commandsCap][7]f32
   * @param commandsLen u8
   * @returns void
   */
  flush_commands(commandsTypesPtr: number, commandsArgsPtr: number, commandsLen: number): void;
  /**
   * @returns void
   */
  js_clear(): void;
  /**
   * @param ptr [*]u8
   * @param len u32
   * @returns void
   */
  js_log_str(ptr: number, len: number): void;
}
