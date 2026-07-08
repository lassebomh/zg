import { fail } from "./lib/utils";

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

// split this so the resize observer isn't linked with the command buffer stuff.

export function canvasResizer({
  canvas,
  onresize,
}: {
  canvas: HTMLCanvasElement;
  onresize: (width: number, height: number) => void;
}) {
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

  return () => {
    resizeObserver.disconnect();
  };
}

export function onResize(element: HTMLElement, onresize: (width: number, height: number) => any, signal: AbortSignal) {
  const observer = new ResizeObserver((entries) => {
    for (const entry of entries) {
      onresize((entry.contentBoxSize.at(0) ?? fail()).inlineSize, (entry.contentBoxSize.at(0) ?? fail()).blockSize);
    }
  });

  observer.observe(element);

  signal.addEventListener("abort", () => {
    observer.disconnect();
  });
}
