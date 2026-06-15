import { Input, inputControl } from "./inputs";
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
    jsLogf32(num: number) {
      console.warn(num);
    },
    jsLogu64(num: number) {
      console.warn(num);
    },
    jsLogu32(num: number) {
      console.warn(num);
    },
    jsFlushCommands(commandsTypesPtr: number, commandsArgsPtr: number, commandsLen: number) {
      // let last = 0;
      // for (let i = 0; i < 32; i++) {
      //   let str = "";
      //   for (let i = 0; i < 32; i++) {
      //     str += crypto.randomUUID();
      //   }
      //   last = last ^ str.split("").reduce((acc, x) => acc + (x.codePointAt(0) ?? 0), 0);
      //   console.log(last);
      // }
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
            ctx.fillStyle = `rgb(${a} ${b} ${c} / ${d})`;
            continue;
          case CommandType.strokeStyle:
            ctx.strokeStyle = `rgb(${a} ${b} ${c} / ${d})`;
            continue;
          case CommandType.shadowColor:
            ctx.shadowColor = `rgb(${a} ${b} ${c} / ${d})`;
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

const { memory, main, frame, getInputsPtr, ...unused } = instance.exports as any;
const unusedNames = Object.keys(unused);
if (unusedNames.length) throw new Error(`Unused export(s): ${unusedNames.join(", ")}`);

main();

const frameTimingsLength = 1 << 8;
const frameTimings = new Uint32Array(frameTimingsLength);
let frameCounter = 0;
const frameTimeElement = document.getElementById("frameTime")!;

let animationFrameRequestId: number | undefined;

function render() {
  if (width === 0 || height === 0) return;

  const t0 = performance.now();
  frame(t0, width, height);
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

const io = inputControl(canvas, new Float32Array(memory.buffer, getInputsPtr(), Input.__length__ * 4));

export {};
