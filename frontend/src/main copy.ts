import { inputControl, localId } from "./inputs";
import init from "./wasm/main.wasm?init";

enum CommandType {
  none,

  save,
  restore,

  beginPath,
  moveTo,
  lineTo,
  arc,
  ellipse,
  quadraticCurveTo,
  bezierCurveTo,

  stroke,
  fill,

  fillRect,
  strokeRect,
  clearRect,

  translate,
  scale,
  rotate,

  lineWidth,

  fillStyle,
  strokeStyle,
  shadowColor,
}

function isUnreachable(value: never): never {
  throw new Error("Unreachable");
}

function rgbaToString(r: number, g: number, b: number, alpha: number): string {
  if (alpha === 1) {
    return "rgb(" + r + " " + g + " " + b + ")";
  } else {
    return "rgb(" + r + " " + g + " " + b + "/" + alpha + ")";
  }
}

const canvas = document.getElementById("canvas") as HTMLCanvasElement;
const ctx = canvas.getContext("2d")!;
let width = 0;
let height = 0;

const resizeObserver = new ResizeObserver((entries) => {
  for (const entry of entries) {
    width = entry.contentBoxSize[0].inlineSize;
    height = entry.contentBoxSize[0].blockSize;
    canvas.width = width;
    canvas.height = height;
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";
    if (animationFrameRequestId) cancelAnimationFrame(animationFrameRequestId);
    render();
  }
});

const instance = await init({
  env: {
    jsLogStr(ptr: number, length: number) {
      const buffer = (instance.exports.memory as WebAssembly.Memory).buffer;
      const dec = new TextDecoder();
      const chars = new Uint8Array(buffer, ptr, length);
      console.log(dec.decode(chars));
    },
    jsFlushCommands(commandsTypesPtr: number, commandsArgsPtr: number, commandsLen: number) {
      const buffer = (instance.exports.memory as WebAssembly.Memory).buffer;
      const commandsTypes = new Uint32Array(buffer, commandsTypesPtr, commandsLen);
      const commandsArgs = new Float32Array(buffer, commandsArgsPtr, commandsLen * 7);
      for (let i = 0; i < commandsLen; i++) {
        const type: CommandType = commandsTypes[i];
        const offset = i * 7;

        const a = commandsArgs[offset];
        const b = commandsArgs[offset + 1];
        const c = commandsArgs[offset + 2];
        const d = commandsArgs[offset + 3];
        const e = commandsArgs[offset + 4];
        const f = commandsArgs[offset + 5];
        const g = commandsArgs[offset + 6];

        switch (type) {
          case CommandType.none:
            continue;

          case CommandType.save:
            ctx.save();
            continue;
          case CommandType.restore:
            ctx.restore();
            continue;

          case CommandType.stroke:
            ctx.stroke();
            continue;
          case CommandType.fill:
            ctx.fill();
            continue;

          case CommandType.beginPath:
            ctx.beginPath();
            continue;
          case CommandType.rotate:
            ctx.rotate(a);
            continue;
          case CommandType.lineWidth:
            ctx.lineWidth = a;
            continue;
          case CommandType.moveTo:
            ctx.moveTo(a, b);
            continue;
          case CommandType.lineTo:
            ctx.lineTo(a, b);
            continue;
          case CommandType.translate:
            ctx.translate(a, b);
            continue;
          case CommandType.scale:
            ctx.scale(a, b);
            continue;

          case CommandType.quadraticCurveTo:
            ctx.quadraticCurveTo(a, b, c, d);
            continue;
          case CommandType.fillRect:
            ctx.fillRect(a, b, c, d);
            continue;
          case CommandType.strokeRect:
            ctx.strokeRect(a, b, c, d);
            continue;
          case CommandType.clearRect:
            ctx.clearRect(a, b, c, d);
            continue;

          case CommandType.fillStyle:
            ctx.fillStyle = rgbaToString(a, b, c, d);
            continue;
          case CommandType.strokeStyle:
            ctx.strokeStyle = rgbaToString(a, b, c, d);
            continue;
          case CommandType.shadowColor:
            ctx.shadowColor = rgbaToString(a, b, c, d);
            continue;

          case CommandType.arc:
            ctx.arc(a, b, c, d, e);
            continue;

          case CommandType.bezierCurveTo:
            ctx.bezierCurveTo(a, b, c, d, e, f);
            continue;

          case CommandType.ellipse:
            ctx.ellipse(a, b, c, d, e, f, g);
            continue;

          default:
            isUnreachable(type);
        }
      }
    },
  },
});

const { memory, main, onAnimationFrame, getInputsPtr, ...unused } = instance.exports as any;
const unusedNames = Object.keys(unused);
if (unusedNames.length) throw new Error(`Unused export(s): ${unusedNames.join(", ")}`);

main();

const frameTimingsLength = 1 << 8;
const frameTimings = new Uint32Array(frameTimingsLength);
let frameCounter = 0;
const frameTimeElement = document.getElementById("frameTime")!;

let animationFrameRequestId: number | undefined;

let last_t = performance.now();
let time = 0;
let timescale = 1;

function render() {
  if (width === 0 || height === 0) return;

  const t0 = performance.now();
  const dt = (t0 - last_t) * timescale;
  last_t = t0;

  time += dt;

  onAnimationFrame(time, width, height, localId);
  const t1 = performance.now();
  frameTimings[frameCounter++ & (frameTimingsLength - 1)] = t1 - t0;
  animationFrameRequestId = requestAnimationFrame(render);
}

setInterval(() => {
  if (frameCounter > frameTimingsLength) {
    const msBudget = 1000 / 144;
    const ms = (Math.min(...frameTimings) + Math.max(...frameTimings)) / 2;
    const pctOfBudget = (ms / msBudget) * 100;
    frameTimeElement.textContent = pctOfBudget.toFixed(3) + "%";
  }
}, 1000);

resizeObserver.observe(document.body);

window.addEventListener("keydown", (e) => {
  if (e.key === "1" && e.ctrlKey) {
    e.preventDefault();
    console.clear();
  } else if (e.key === "2" && e.ctrlKey) {
    e.preventDefault();
    timescale = 1;
  } else if (e.key === "3" && e.ctrlKey) {
    e.preventDefault();
    timescale = 0.02;
  } else if (e.key === "4" && e.ctrlKey) {
    e.preventDefault();
    timescale = 0;
    time += 1000 / 60;
  }
});

const io = inputControl(canvas, () => new DataView(memory.buffer, getInputsPtr()));

export {};
