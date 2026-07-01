import init from "./wasm/main.wasm?init";
import * as twgl from "twgl.js";

const canvas1 = document.getElementById("canvas1")! as HTMLCanvasElement;
const canvas3 = document.getElementById("canvas3")! as HTMLCanvasElement;
const canvas4 = document.getElementById("canvas4")! as HTMLCanvasElement;

for (const c of [canvas1, canvas3, canvas4]) {
  c.style.imageRendering = "pixelated";
  c.style.border = "none";
  c.style.outline = "1px solid red";
  c.style.outlineOffset = "0px";
}

instantiate();

async function instantiate() {
  let flushCanvas: (() => void) | undefined;

  const instance = await init({
    env: {
      jsLogStr(ptr: number, length: number) {
        const buffer = (instance.exports.memory as WebAssembly.Memory).buffer;
        const dec = new TextDecoder();
        const chars = new Uint8Array(buffer, ptr, length);
        console.log(dec.decode(chars));
      },
      jsClear() {
        console.clear();
      },
      js_flush_canvas() {
        flushCanvas?.();
      },
    },
  });

  const {
    memory,
    js_get_color_tex_offset,
    js_get_height_tex_offset,
    js_get_color_tex_len,
    js_get_height_tex_len,
    js_render,
    js_get_ubo_offset,
    js_get_ubo_size,
    ...unused
  } = instance.exports as any;
  const unusedNames = Object.keys(unused);
  if (unusedNames.length) throw new Error(`Unused export(s): ${unusedNames.join(", ")}`);

  const gl = canvas4.getContext("webgl2")!;
  gl.getExtension("EXT_color_buffer_float");

  const vsSource = `#version 300 es
in vec2 aPos;
out vec2 vUv;
void main() {
  vUv = aPos * 0.5 + 0.5;
  gl_Position = vec4(aPos, 0.0, 1.0);
}`;

  const lightingFs = `#version 300 es
precision highp float;

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uHeight;

#define MAX_LIGHTS 8

struct Light {
  int mode;
  float intensity;
  float spot_cutoff;
  float _pad1;
  vec3 pos;
  float _pad2;
  vec3 target;
  float _pad3;
  vec3 color;
  float _pad4;
};

layout(std140) uniform SceneBlock {
  int render_width;
  int render_height;
  int render_x;
  int render_y;

  int light_width;
  int light_height;
  int light_x;
  int light_y;

  int light_dx;
  int light_dy;

  float screen_width;
  float screen_height;

  float screen_x;
  float screen_y;

  int lights_len;
  int _pad0;

  Light lights[MAX_LIGHTS];
};

float getHeight(ivec2 world) {
  ivec2 tc = world - ivec2(render_x, render_y);
  if (tc.x < 0 || tc.x >= render_width || tc.y < 0 || tc.y >= render_height) return 0.0;
  return texelFetch(uHeight, tc, 0).r;
}

bool isOccluded(ivec2 worldPx, float pz, vec3 lightPos) {
  vec2 start = vec2(worldPx);
  vec2 end = lightPos.xy;
  vec2 dir = end - start;
  float dist = length(dir);
  int steps = int(dist);
  if (steps == 0) return false;
  vec2 step = dir / float(steps);

  for (int i = 1; i < steps; i++) {
    vec2 samplePos = start + step * float(i);
    ivec2 sp = ivec2(samplePos);
    float h = getHeight(sp);
    float t = float(i) / float(steps);
    float rayZ = mix(pz, lightPos.z, t);
    if (h > rayZ) return true;
  }
  return false;
}

void main() {
  ivec2 lightTexel = ivec2(gl_FragCoord.xy);
  ivec2 world = lightTexel + ivec2(light_x, light_y);

  float h = getHeight(world);

  vec3 totalLight = vec3(0.02);

  for (int i = 0; i < MAX_LIGHTS; i++) {
    if (i >= lights_len) break;

    vec3 lp = lights[i].pos;
    vec3 lc = lights[i].color;
    float li = lights[i].intensity;

    vec3 toLight = lp - vec3(vec2(world), h);
    float d = length(toLight);
    float atten = li / (1.0 + d * 0.05 + d * d * 0.005);

    if (!isOccluded(world, h, lp)) {
      totalLight += lc * atten;
    }
  }

  fragColor = vec4(totalLight, 1.0);
}`;

  const accFs = `#version 300 es
precision highp float;

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uCurrentLight;
uniform sampler2D uPrevAcc;

#define MAX_LIGHTS 8

struct Light {
  int mode;
  float intensity;
  float spot_cutoff;
  float _pad1;
  vec3 pos;
  float _pad2;
  vec3 target;
  float _pad3;
  vec3 color;
  float _pad4;
};

layout(std140) uniform SceneBlock {
  int render_width;
  int render_height;
  int render_x;
  int render_y;

  int light_width;
  int light_height;
  int light_x;
  int light_y;

  int light_dx;
  int light_dy;

  float screen_width;
  float screen_height;

  float screen_x;
  float screen_y;

  int lights_len;
  int frame;

  Light lights[MAX_LIGHTS];
};

void main() {
  ivec2 texel = ivec2(gl_FragCoord.xy);
  vec3 current = texelFetch(uCurrentLight, texel, 0).rgb;

  ivec2 prevTexel = texel + ivec2(light_dx, light_dy);

  vec3 prev;
  if (prevTexel.x < 0 || prevTexel.x >= light_width || prevTexel.y < 0 || prevTexel.y >= light_height) {
    prev = current;
  } else {
    prev = texelFetch(uPrevAcc, prevTexel, 0).rgb;
  }

  fragColor = vec4(mix(prev, current, 1.0), 1.0);
}`;

  const compositeFs = `#version 300 es
precision highp float;

in vec2 vUv;
out vec4 fragColor;

uniform sampler2D uColor;
uniform sampler2D uAcc;

#define MAX_LIGHTS 8

struct Light {
  int mode;
  float intensity;
  float spot_cutoff;
  float _pad1;
  vec3 pos;
  float _pad2;
  vec3 target;
  float _pad3;
  vec3 color;
  float _pad4;
};

layout(std140) uniform SceneBlock {
  int render_width;
  int render_height;
  int render_x;
  int render_y;

  int light_width;
  int light_height;
  int light_x;
  int light_y;

  int light_dx;
  int light_dy;

  float screen_width;
  float screen_height;

  float screen_x;
  float screen_y;

  int lights_len;
  int _pad0;

  Light lights[MAX_LIGHTS];
};

void main() {
  vec2 screenPixel = vec2(gl_FragCoord.x, screen_height - gl_FragCoord.y);
  vec2 world = screenPixel + vec2(screen_x, screen_y);

  ivec2 colorTexel = ivec2(world) - ivec2(render_x, render_y);
  ivec2 lightTexel = ivec2(world) - ivec2(light_x, light_y);

  if (colorTexel.x < 0 || colorTexel.x >= render_width || colorTexel.y < 0 || colorTexel.y >= render_height) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }

  vec4 col = texelFetch(uColor, colorTexel, 0);
  if (col.a == 0.0) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }

  if (lightTexel.x < 0 || lightTexel.x >= light_width || lightTexel.y < 0 || lightTexel.y >= light_height) {
    fragColor = vec4(col.rgb * 0.02, 1.0);
    return;
  }

  vec3 light = texelFetch(uAcc, lightTexel, 0).rgb;
  fragColor = vec4(col.rgb * light, 1.0);
}`;

  const lightingProg = twgl.createProgramInfo(gl, [vsSource, lightingFs]);
  const accProg = twgl.createProgramInfo(gl, [vsSource, accFs]);
  const compositeProg = twgl.createProgramInfo(gl, [vsSource, compositeFs]);

  const quadBuf = twgl.createBufferInfoFromArrays(gl, {
    aPos: { numComponents: 2, data: [-1, -1, 1, -1, -1, 1, 1, 1] },
  });

  const uboBuffer = gl.createBuffer()!;
  gl.bindBuffer(gl.UNIFORM_BUFFER, uboBuffer);
  gl.bufferData(gl.UNIFORM_BUFFER, js_get_ubo_size(), gl.DYNAMIC_DRAW);
  gl.bindBufferBase(gl.UNIFORM_BUFFER, 0, uboBuffer);

  for (const prog of [lightingProg, accProg, compositeProg]) {
    const idx = gl.getUniformBlockIndex(prog.program, "SceneBlock");
    gl.uniformBlockBinding(prog.program, idx, 0);
  }

  let colorTex: WebGLTexture | null = null;
  let heightTex: WebGLTexture | null = null;
  let lightFbo: twgl.FramebufferInfo | null = null;
  let accFbos: [twgl.FramebufferInfo, twgl.FramebufferInfo] | null = null;
  let accIndex = 0;

  let prevRenderW = 0,
    prevRenderH = 0;
  let prevLightW = 0,
    prevLightH = 0;

  function ensureTextures(rw: number, rh: number, lw: number, lh: number) {
    if (rw !== prevRenderW || rh !== prevRenderH) {
      if (colorTex) gl.deleteTexture(colorTex);
      if (heightTex) gl.deleteTexture(heightTex);

      colorTex = twgl.createTexture(gl, {
        width: rw,
        height: rh,
        minMag: gl.NEAREST,
        wrap: gl.CLAMP_TO_EDGE,
        internalFormat: gl.RGBA8,
        format: gl.RGBA,
        type: gl.UNSIGNED_BYTE,
        auto: false,
      });
      heightTex = twgl.createTexture(gl, {
        width: rw,
        height: rh,
        minMag: gl.NEAREST,
        wrap: gl.CLAMP_TO_EDGE,
        internalFormat: gl.R32F,
        format: gl.RED,
        type: gl.FLOAT,
        auto: false,
      });
      prevRenderW = rw;
      prevRenderH = rh;
    }

    if (lw !== prevLightW || lh !== prevLightH) {
      if (lightFbo) {
        twgl.resizeFramebufferInfo(gl, lightFbo, [{ internalFormat: gl.RGBA16F }], lw, lh);
      } else {
        lightFbo = twgl.createFramebufferInfo(gl, [{ internalFormat: gl.RGBA16F, minMag: gl.NEAREST }], lw, lh);
        lightFbo = twgl.createFramebufferInfo(gl, [{ internalFormat: gl.RGBA16F, minMag: gl.NEAREST }], lw, lh);
        twgl.bindFramebufferInfo(gl, lightFbo);
        gl.clearColor(0, 0, 0, 1);
        gl.clear(gl.COLOR_BUFFER_BIT);
      }

      if (accFbos) {
        for (const fb of accFbos) {
          twgl.resizeFramebufferInfo(gl, fb, [{ internalFormat: gl.RGBA16F }], lw, lh);
        }
      } else {
        accFbos = [
          twgl.createFramebufferInfo(gl, [{ internalFormat: gl.RGBA16F, minMag: gl.NEAREST }], lw, lh),
          twgl.createFramebufferInfo(gl, [{ internalFormat: gl.RGBA16F, minMag: gl.NEAREST }], lw, lh),
        ];
        for (const fb of accFbos) {
          twgl.bindFramebufferInfo(gl, fb);
          gl.clearColor(0, 0, 0, 1);
          gl.clear(gl.COLOR_BUFFER_BIT);
        }
      }
      prevLightW = lw;
      prevLightH = lh;
    }
  }

  function blitToCanvas(
    target: HTMLCanvasElement,
    texture: WebGLTexture,
    w: number,
    h: number,
    isFloat: boolean = false,
  ) {
    target.width = w;
    target.height = h;
    const fb = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);

    const ctx = target.getContext("2d")!;
    const imgData = ctx.createImageData(w, h);

    if (isFloat) {
      const floats = new Float32Array(w * h * 4);
      gl.readPixels(0, 0, w, h, gl.RGBA, gl.FLOAT, floats);
      for (let i = 0; i < w * h * 4; i++) {
        imgData.data[i] = Math.min(255, Math.max(0, Math.round(floats[i] * 255)));
      }
    } else {
      const pixels = new Uint8Array(w * h * 4);
      gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
      imgData.data.set(pixels);
    }

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.deleteFramebuffer(fb);
    ctx.putImageData(imgData, 0, 0);
  }

  flushCanvas = () => {
    const uboBytes = new Uint8Array(memory.buffer, js_get_ubo_offset(), js_get_ubo_size());
    const uboView = new DataView(memory.buffer, js_get_ubo_offset(), js_get_ubo_size());

    const renderW = uboView.getInt32(0, true);
    const renderH = uboView.getInt32(4, true);
    const lightW = uboView.getInt32(16, true);
    const lightH = uboView.getInt32(20, true);
    const screenW = uboView.getFloat32(40, true);
    const screenH = uboView.getFloat32(44, true);

    if (renderW <= 0 || renderH <= 0 || lightW <= 0 || lightH <= 0 || screenW <= 0 || screenH <= 0) {
      requestAnimationFrame(frame);
      return;
    }

    ensureTextures(renderW, renderH, lightW, lightH);

    // Upload UBO
    gl.bindBuffer(gl.UNIFORM_BUFFER, uboBuffer);
    gl.bufferSubData(gl.UNIFORM_BUFFER, 0, uboBytes);

    // Upload color + height
    const colorData = new Uint8Array(memory.buffer, js_get_color_tex_offset(), js_get_color_tex_len() * 4);
    const heightData = new Float32Array(memory.buffer, js_get_height_tex_offset(), js_get_height_tex_len());

    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, colorTex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, renderW, renderH, 0, gl.RGBA, gl.UNSIGNED_BYTE, colorData);

    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, heightTex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.R32F, renderW, renderH, 0, gl.RED, gl.FLOAT, heightData);

    // Pass 1: Lighting
    twgl.bindFramebufferInfo(gl, lightFbo);
    gl.viewport(0, 0, lightW, lightH);
    gl.useProgram(lightingProg.program);
    twgl.setBuffersAndAttributes(gl, lightingProg, quadBuf);
    twgl.setUniforms(lightingProg, { uHeight: heightTex });
    twgl.drawBufferInfo(gl, quadBuf, gl.TRIANGLE_STRIP);

    // Pass 2: Accumulation
    const src = accIndex;
    const dst = 1 - accIndex;
    twgl.bindFramebufferInfo(gl, accFbos![dst]);
    gl.viewport(0, 0, lightW, lightH);
    gl.useProgram(accProg.program);
    twgl.setBuffersAndAttributes(gl, accProg, quadBuf);
    twgl.setUniforms(accProg, {
      uCurrentLight: lightFbo!.attachments[0],
      uPrevAcc: accFbos![src].attachments[0],
    });
    twgl.drawBufferInfo(gl, quadBuf, gl.TRIANGLE_STRIP);
    accIndex = dst;

    // Pass 3: Composite
    twgl.bindFramebufferInfo(gl, null);
    canvas4.width = Math.ceil(screenW);
    canvas4.height = Math.ceil(screenH);
    gl.viewport(0, 0, canvas4.width, canvas4.height);
    gl.useProgram(compositeProg.program);
    twgl.setBuffersAndAttributes(gl, compositeProg, quadBuf);
    twgl.setUniforms(compositeProg, {
      uColor: colorTex,
      uAcc: accFbos![accIndex].attachments[0],
    });
    twgl.drawBufferInfo(gl, quadBuf, gl.TRIANGLE_STRIP);

    // Debug
    blitToCanvas(canvas1, colorTex!, renderW, renderH, false);
    blitToCanvas(canvas3, accFbos![accIndex].attachments[0], lightW, lightH, true);
  };

  function frame() {
    js_render(canvas4.width, canvas4.height);

    requestAnimationFrame(frame);
  }

  requestAnimationFrame(frame);
}
