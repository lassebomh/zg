// AUTO-GENERATED

export type opaque_ptr = { readonly _: unique symbol};


export interface WasmFnExports {
  /**
   * @returns *Input
   */
  jsGetInputBufferPtr(): number;
  /**
   * @param peer_id i32
   * @returns usize
   */
  jsGetPeerInputsLen(peer_id: number): number;
  /**
   * @param peer_id i32
   * @returns [*]Input
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
  /**
   * @param enabled i32
   * @param x f32
   * @param y f32
   * @param z f32
   * @param pitch f32
   * @param yaw f32
   * @param scale f32
   * @param width i32
   * @param height i32
   * @returns void
   */
  jsUpdateDebugCamera(enabled: number, x: number, y: number, z: number, pitch: number, yaw: number, scale: number, width: number, height: number): void;
}

export interface WasmEnv {
  /**
   * @param target GLEnum_FramebufferOrRenderbuffer
   * @param framebuffer *anyopaque
   * @returns void
   */
  _bindFramebuffer(target: number, framebuffer: opaque_ptr): void;
  /**
   * @param vao *anyopaque
   * @returns void
   */
  _bindVertexArray(vao: opaque_ptr): void;
  /**
   * @param target GLEnum_Buffer
   * @param dataPtr [*]const f32
   * @param dataLen i32
   * @param usage GLEnum_Buffer
   * @returns void
   */
  _bufferDataf(target: number, dataPtr: number, dataLen: number, usage: number): void;
  /**
   * @param target GLEnum_Buffer
   * @param dataPtr [*]const u32
   * @param dataLen i32
   * @param usage GLEnum_Buffer
   * @returns void
   */
  _bufferDatau(target: number, dataPtr: number, dataLen: number, usage: number): void;
  /**
   * @param program *anyopaque
   * @param namePtr [*]const u8
   * @param nameLen i32
   * @returns i32
   */
  _getAttribLocation(program: opaque_ptr, namePtr: number, nameLen: number): number;
  /**
   * @param program *anyopaque
   * @param namePtr [*]const u8
   * @param nameLen i32
   * @returns *anyopaque
   */
  _getUniformLocation(program: opaque_ptr, namePtr: number, nameLen: number): opaque_ptr;
  /**
   * @param shader *anyopaque
   * @param sourcePtr [*]const u8
   * @param sourceLen i32
   * @returns void
   */
  _shaderSource(shader: opaque_ptr, sourcePtr: number, sourceLen: number): void;
  /**
   * @param target GLEnum_FramebufferOrRenderbuffer
   * @returns void
   */
  _unbindFramebuffer(target: number): void;
  /**
   * @returns void
   */
  _unbindVertexArray(): void;
  /**
   * @param uniform *anyopaque
   * @param transpose i32
   * @param valuePtr [*]const f32
   * @param valueLen i32
   * @returns void
   */
  _uniformMatrix4fv(uniform: opaque_ptr, transpose: number, valuePtr: number, valueLen: number): void;
  /**
   * @param index i32
   * @param size i32
   * @param type GLEnum_DataType
   * @param normalized i32
   * @param stride i32
   * @param offset i32
   * @returns void
   */
  _vertexAttribPointer(index: number, size: number, type: number, normalized: number, stride: number, offset: number): void;
  /**
   * @param target GLEnum_Texture
   * @returns void
   */
  activeTexture(target: number): void;
  /**
   * @param program *anyopaque
   * @param shader *anyopaque
   * @returns void
   */
  attachShader(program: opaque_ptr, shader: opaque_ptr): void;
  /**
   * @param target GLEnum_Buffer
   * @param buffer *anyopaque
   * @returns void
   */
  bindBuffer(target: number, buffer: opaque_ptr): void;
  /**
   * @param target GLEnum_Texture
   * @param texture *anyopaque
   * @returns void
   */
  bindTexture(target: number, texture: opaque_ptr): void;
  /**
   * @param mask i32
   * @returns void
   */
  clear(mask: number): void;
  /**
   * @param shader *anyopaque
   * @returns void
   */
  compileShader(shader: opaque_ptr): void;
  /**
   * @returns *anyopaque
   */
  createBuffer(): opaque_ptr;
  /**
   * @returns *anyopaque
   */
  createFrameBuffer(): opaque_ptr;
  /**
   * @returns *anyopaque
   */
  createProgram(): opaque_ptr;
  /**
   * @param shaderType GLEnum_Shader
   * @returns *anyopaque
   */
  createShader(shaderType: number): opaque_ptr;
  /**
   * @returns *anyopaque
   */
  createTexture(): opaque_ptr;
  /**
   * @returns *anyopaque
   */
  createVertexArray(): opaque_ptr;
  /**
   * @param cap GLEnum_EnableDisable
   * @returns void
   */
  disable(cap: number): void;
  /**
   * @param mode GLEnum_RenderPrimitive
   * @param first i32
   * @param count i32
   * @returns void
   */
  drawArrays(mode: number, first: number, count: number): void;
  /**
   * @param mode GLEnum_RenderPrimitive
   * @param count i32
   * @param type GLEnum_DataType
   * @param offset i32
   * @returns void
   */
  drawElements(mode: number, count: number, type: number, offset: number): void;
  /**
   * @param mode GLEnum_RenderPrimitive
   * @param count i32
   * @param type GLEnum_DataType
   * @param offset i32
   * @param instanceCount i32
   * @returns void
   */
  drawElementsInstanced(mode: number, count: number, type: number, offset: number, instanceCount: number): void;
  /**
   * @param cap GLEnum_EnableDisable
   * @returns void
   */
  enable(cap: number): void;
  /**
   * @param attribLocation i32
   * @returns void
   */
  enableVertexAttribArray(attribLocation: number): void;
  /**
   * @param commandsTypesPtr *[commandsCap]CommandType
   * @param commandsArgsPtr *[commandsCap][7]f32
   * @param commandsLen u8
   * @returns void
   */
  flush_commands(commandsTypesPtr: number, commandsArgsPtr: number, commandsLen: number): void;
  /**
   * @param target GLEnum_FramebufferOrRenderbuffer
   * @param attachment GLEnum_FramebufferOrRenderbuffer
   * @param textarget GLEnum_Texture
   * @param texture *anyopaque
   * @param level i32
   * @returns void
   */
  framebufferTexture2D(target: number, attachment: number, textarget: number, texture: opaque_ptr, level: number): void;
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
  /**
   * @param program *anyopaque
   * @returns void
   */
  linkProgram(program: opaque_ptr): void;
  /**
   * @param target GLEnum_Texture
   * @param level i32
   * @param internalformat GLEnum_Texture
   * @param width i32
   * @param height i32
   * @param border i32
   * @param format GLEnum_PixelFormat
   * @param type GLEnum_DataType
   * @returns void
   */
  texImage2D(target: number, level: number, internalformat: number, width: number, height: number, border: number, format: number, type: number): void;
  /**
   * @param target GLEnum_Texture
   * @param pname GLEnum_Texture
   * @param param GLEnum_Texture
   * @returns void
   */
  texParameteri(target: number, pname: number, param: number): void;
  /**
   * @param uniform *anyopaque
   * @param value f32
   * @returns void
   */
  uniform1f(uniform: opaque_ptr, value: number): void;
  /**
   * @param uniform *anyopaque
   * @param value i32
   * @returns void
   */
  uniform1i(uniform: opaque_ptr, value: number): void;
  /**
   * @param uniform *anyopaque
   * @param x f32
   * @param y f32
   * @returns void
   */
  uniform2f(uniform: opaque_ptr, x: number, y: number): void;
  /**
   * @param program *anyopaque
   * @returns void
   */
  useProgram(program: opaque_ptr): void;
  /**
   * @param index i32
   * @param divisor i32
   * @returns void
   */
  vertexAttribDivisor(index: number, divisor: number): void;
  /**
   * @param x i32
   * @param y i32
   * @param w i32
   * @param h i32
   * @returns void
   */
  viewport(x: number, y: number, w: number, h: number): void;
}
