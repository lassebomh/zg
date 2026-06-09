import init from "./wasm/main.wasm?init";

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
    /**
     * @param {number} num
     */
    jsLogf32(num: number) {
      console.warn(num);
    },
    jsLogu64(num: number) {
      console.warn(num);
    },
    jsLogu32(num: number) {
      console.warn(num);
    },
  },
});

const { memory, main, frame, getMaxCommands, getCommandsArgsPtr, getCommandsTypesPtr, getCommandsLength, ...unused } =
  instance.exports as any;
const unusedNames = Object.keys(unused);
if (unusedNames.length) throw new Error(`Unused export(s): ${unusedNames.join(", ")}`);

const buffer = (memory as WebAssembly.Memory).buffer;

const MAX_COMMANDS: number = getMaxCommands();

const commandsTypes = new Uint32Array(buffer, getCommandsTypesPtr(), MAX_COMMANDS);
const commandsArgs = new Float32Array(buffer, getCommandsArgsPtr(), MAX_COMMANDS * 7);

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

main();

let animationFrameRequestId: number | undefined;

function render() {
  if (width === 0 || height === 0) return;

  frame(performance.now(), width, height);

  const commandsLength = getCommandsLength();

  for (let i = 0; i < commandsLength; i++) {
    const type: CommandType = commandsTypes[i];

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
    }

    const offset = i * 7;

    const a = commandsArgs[offset];

    switch (type) {
      case CommandType.rotate:
        ctx.rotate(a);
        continue;
      case CommandType.lineWidth:
        ctx.lineWidth = a;
        continue;
    }
    const b = commandsArgs[offset + 1];

    switch (type) {
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
    }
    const c = commandsArgs[offset + 2];
    const d = commandsArgs[offset + 3];

    switch (type) {
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
    }

    const e = commandsArgs[offset + 4];
    switch (type) {
      case CommandType.arc:
        ctx.arc(a, b, c, d, e);
        continue;
    }

    const f = commandsArgs[offset + 5];
    switch (type) {
      case CommandType.bezierCurveTo:
        ctx.bezierCurveTo(a, b, c, d, e, f);
        continue;
    }

    const g = commandsArgs[offset + 6];
    switch (type) {
      case CommandType.ellipse:
        ctx.ellipse(a, b, c, d, e, f, g);
        continue;
    }

    isUnreachable(type);
  }

  animationFrameRequestId = requestAnimationFrame(render);
}

resizeObserver.observe(document.body);

export {};
