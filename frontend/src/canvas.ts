import { fail, isUnreachable } from "./lib/utils";

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

function rgbaToString(r: number, g: number, b: number, alpha: number): string {
  if (alpha === 1) {
    return "rgb(" + r + " " + g + " " + b + ")";
  } else {
    return "rgb(" + r + " " + g + " " + b + "/" + alpha + ")";
  }
}

export function attachCanvas({
  canvas,
  onresize,
}: {
  canvas: HTMLCanvasElement;
  onresize: (width: number, height: number) => void;
}) {
  const ctx = canvas.getContext("2d") ?? fail();
  let width = 0;
  let height = 0;

  const resizeObserver = new ResizeObserver((entries) => {
    for (const entry of entries) {
      width = entry.contentBoxSize[0].inlineSize;
      height = entry.contentBoxSize[0].blockSize;
      canvas.width = width;
      canvas.height = height;
      onresize(width, height);
    }
  });

  resizeObserver.observe(canvas);

  return {
    context: ctx,

    destroy() {
      resizeObserver.disconnect();
    },

    send(buffer: ArrayBuffer, commandsTypesPtr: number, commandsArgsPtr: number, commandsLen: number) {
      // const buffer = (instance.exports.memory as WebAssembly.Memory).buffer;
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
  };
}
