import { struct, u32, array, taggedUnion } from "./struct";

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
    canvas.width = width * devicePixelRatio;
    canvas.height = height * devicePixelRatio;
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";
    ctx.scale(devicePixelRatio, devicePixelRatio);
    render();
  }
});

const wasm = await WebAssembly.instantiateStreaming(fetch("./main.wasm"), {
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

const { memory, main, frame, getInputPtr, getInputLen, getOutputPtr, ...unused } = wasm.instance.exports as any;

const buffer = (memory as WebAssembly.Memory).buffer;

const unusedNames = Object.keys(unused);
if (unusedNames.length) throw new Error(`Unused export(s): ${unusedNames.join(", ")}`);

const input = new Uint8Array(buffer, getInputPtr(), getInputLen());

const Commands = struct({
  length: u32,
  items: array(
    8,
    taggedUnion({
      clearRect: struct({ x: u32, y: u32, width: u32, height: u32 }),
      fillRect: struct({ x: u32, y: u32, width: u32, height: u32 }),
    }),
  ),
});

const commandsView = Commands.createView();

commandsView.bind(buffer, getOutputPtr());

const commands = commandsView.get();

main();

let animationFrameRequestId: number | undefined;

function render() {
  if (width === 0 || height === 0) return;
  if (animationFrameRequestId) {
    cancelAnimationFrame(animationFrameRequestId);
    animationFrameRequestId = undefined;
  }

  frame(performance.timeOrigin + performance.now(), width, height);

  for (let i = 0; i < commands.length; i++) {
    const command = commands.items[i];
    switch (command.tag) {
      case "clearRect":
        ctx.clearRect(command.payload.x, command.payload.y, command.payload.width, command.payload.height);
        break;
      case "fillRect":
        ctx.fillRect(command.payload.x, command.payload.y, command.payload.width, command.payload.height);
        break;

      default:
        isUnreachable(command);
    }
  }
  animationFrameRequestId = requestAnimationFrame(render);
}

resizeObserver.observe(document.body);

export {};
