<script lang="ts" module>
  let sendCanvasCommands:
    | ((commandsTypesPtr: number, commandsArgsPtr: number, commandsLen: number) => void)
    | undefined;

  const instance = await init({
    env: {
      jsLogStr(ptr: number, length: number) {
        const buffer = (instance.exports.memory as WebAssembly.Memory).buffer;
        const dec = new TextDecoder();
        const chars = new Uint8Array(buffer, ptr, length);
        console.log(dec.decode(chars));
      },
      jsFlushCommands(commandsTypesPtr: number, commandsArgsPtr: number, commandsLen: number) {
        sendCanvasCommands?.(commandsTypesPtr, commandsArgsPtr, commandsLen);
      },
    },
  });

  const {
    memory,
    jsRenderTick,
    jsPullInputBuffer,
    jsGetInputBufferPtr,
    jsGetPeerInputsPtr,
    jsGetPeerInputsLen,
    ...unused
  } = instance.exports as any;
  const unusedNames = Object.keys(unused);
  if (unusedNames.length) throw new Error(`Unused export(s): ${unusedNames.join(", ")}`);

  function flushInputBuffer(tick: number, buffer: ArrayBuffer) {
    const inputBytes = new Uint8Array(buffer);
    const memoryBuffer = new Uint8Array(
      (instance.exports.memory as WebAssembly.Memory).buffer,
      jsGetInputBufferPtr(),
      inputBytes.byteLength,
    );
    memoryBuffer.set(inputBytes);
    jsPullInputBuffer(tick);
  }

  type UIState = {
    alphaLock: boolean;
    viewStart: number;
    viewEnd: number;
    currentPeerId: number;
    playSpeed: number;
    onion: number;
    loopStart: number | undefined;
    loopEnd: number | undefined;
    loopEnabled: boolean;
    cameraX: number;
    cameraY: number;
    cameraZoomPosition: number;
    cameraZoomPositionChange: number;
    cameraZoom: number;
    stateQuery: string;
  };

  type Save = {
    ui: UIState;
    inputs: Array<ArrayBuffer>;
  };
  const saveStore = await persistent<Save>("save");

  const save = await saveStore.get();
</script>

<script lang="ts">
  import { onMount } from "svelte";
  import { attachCanvas } from "./canvas";
  import init from "./wasm/main.wasm?init";
  import { abortSignal, assert } from "./lib/utils.js";
  import { createInputProxy, InputByteLength, inputControl } from "./inputs";
  import { persistent } from "./storage";

  const PLAYER_COLORS = ["#ef4444", "#3b9eed", "#45b358", "#ebc934"];

  const TICK_RATE = 1000 / 60;

  const temp = $state({
    recording: false,
    playing: 0,
    canvasOverlayPanning: false,
    tracksCanvasPanning: false,
    invalidStateQuery: false,
    viewChange: 0,
  });

  let ui = $state<UIState>({
    alphaLock: false,
    viewStart: -30,
    viewEnd: 30,
    currentPeerId: 1,
    loopStart: undefined,
    loopEnd: undefined,
    loopEnabled: false,
    playSpeed: 0,
    onion: 0,
    cameraX: 0,
    cameraY: 0,
    cameraZoomPosition: 0,
    cameraZoomPositionChange: 0,
    cameraZoom: 1,
    stateQuery: "",
  });

  const playheadTick = $derived(Math.max(0, (ui.viewStart + ui.viewEnd) / 2));
  const tick = $derived(Math.floor(playheadTick));
  const alpha = $derived(ui.alphaLock ? 0 : playheadTick - tick);

  if (save) {
    ui = save.ui;

    for (const inputSlice of save.inputs) {
      const inputsCount = inputSlice.byteLength / InputByteLength;
      assert(inputsCount === Math.floor(inputsCount), "Invalid inputs size");
      for (let i = 0; i < inputsCount; i++) {
        const inputBuffer = inputSlice.slice(i * InputByteLength, (i + 1) * InputByteLength);
        flushInputBuffer(i, inputBuffer);
      }
    }
  }

  let gameWidth = 0;
  let gameHeight = 0;

  let tracksWidth = 0;
  let tracksHeight = 0;

  let gameCanvas: HTMLCanvasElement;
  let tracksCanvas: HTMLCanvasElement;

  const inputBuffer = new ArrayBuffer(InputByteLength);
  const inputProxy = createInputProxy(new DataView(inputBuffer));

  onMount(() => {
    const inputController = inputControl(gameCanvas, inputProxy);

    const saveInterval = setInterval(async () => {
      const save: Save = {
        ui: $state.snapshot(ui),
        inputs: [],
      };

      for (let i = 0; i < 4; i++) {
        const peer = i + 1;
        const inputsPtr = jsGetPeerInputsPtr(peer);
        const inputsLen = jsGetPeerInputsLen(peer);
        if (inputsLen === 0) continue;
        const memory = instance.exports.memory as WebAssembly.Memory;
        save.inputs.push(memory.buffer.slice(inputsPtr, inputsPtr + inputsLen * InputByteLength));
      }
      await saveStore.set(save);
    }, 1000);

    let frameRequest: number;

    function render() {
      jsRenderTick(tick, alpha, gameWidth, gameHeight, ui.currentPeerId);
      renderTracks();
      frameRequest = requestAnimationFrame(render);
    }

    const gameCanvasController = attachCanvas({
      canvas: gameCanvas,
      onresize(width, height) {
        gameWidth = width;
        gameHeight = height;
        cancelAnimationFrame(frameRequest);
        render();
      },
    });

    sendCanvasCommands = (commandsTypesPtr, commandsArgsPtr, commandsLen) => {
      const buffer = (instance.exports.memory as WebAssembly.Memory).buffer;
      gameCanvasController.send(buffer, commandsTypesPtr, commandsArgsPtr, commandsLen);
    };

    const tracksCanvasController = attachCanvas({
      canvas: tracksCanvas,
      onresize(width, height) {
        tracksWidth = width;
        tracksHeight = height;
        cancelAnimationFrame(frameRequest);
        render();
      },
    });

    const tracksCtx = tracksCanvasController.context;

    let prevTime = performance.now();
    function renderTracks() {
      const time = performance.now();
      const dt = time - prevTime;
      prevTime = time;

      if (temp.playing !== 0) {
        temp.viewChange = (dt / TICK_RATE) * temp.playing * Math.pow(2, ui.playSpeed);
      }

      if (!temp.tracksCanvasPanning) {
        ui.viewStart += temp.viewChange;
        ui.viewEnd += temp.viewChange;
        temp.viewChange *= Math.pow(0.5, dt / 150);
      }

      if (temp.tracksCanvasPanning && temp.playing === 0) {
        temp.viewChange *= Math.pow(0.5, dt / 50);
      }

      const viewUnderflow = -Math.min(0, (ui.viewEnd + ui.viewStart) / 2);
      ui.viewEnd += viewUnderflow;
      ui.viewStart += viewUnderflow;
      if (viewUnderflow !== 0) {
        temp.viewChange = 0;
      }

      const w = tracksWidth;
      const h = tracksHeight;
      const dpr = devicePixelRatio;

      tracksCtx.clearRect(0, 0, w, h);

      tracksCtx.textAlign = "center";
      tracksCtx.textBaseline = "top";
      tracksCtx.font = `900 ${10 * dpr}px monospace`;

      const range = ui.viewEnd - ui.viewStart;

      // Center line
      tracksCtx.strokeStyle = "#888888";
      tracksCtx.lineWidth = dpr;
      tracksCtx.beginPath();
      tracksCtx.moveTo(w / 2, 0);
      tracksCtx.lineTo(w / 2, h);
      tracksCtx.stroke();

      // Tick marks
      const logStep = 5;
      const step = Math.max(1, Math.pow(logStep, Math.round(Math.log(range / 20) / Math.log(logStep))));
      const subStep = Math.max(1, step / logStep);
      const firstTick = Math.floor(ui.viewStart / subStep) * subStep;

      for (let tick = firstTick; tick <= ui.viewEnd; tick += subStep) {
        if (tick < -0.000001) {
          continue;
        }
        const x = ((tick - ui.viewStart) / range) * w;
        const isMajor = Math.abs(tick - Math.round(tick / step) * step) < subStep * 0.1;

        if (isMajor) {
          // Major tick line
          tracksCtx.strokeStyle = "#666666";
          tracksCtx.lineWidth = dpr;
          tracksCtx.beginPath();
          tracksCtx.moveTo(x, 0);
          tracksCtx.lineTo(x, h);
          tracksCtx.stroke();
        } else {
          // Minor tick line
          tracksCtx.strokeStyle = "#444444";
          tracksCtx.lineWidth = dpr;
          tracksCtx.beginPath();
          tracksCtx.moveTo(x, 0);
          tracksCtx.lineTo(x, h);
          tracksCtx.stroke();
        }
      }

      const grad = tracksCtx.createLinearGradient(0, 0, 0, h);
      grad.addColorStop(0, "#fff0");
      grad.addColorStop(0.15, "#fff0");
      grad.addColorStop(0.5, "#ffff");
      tracksCtx.fillStyle = grad;
      tracksCtx.strokeStyle = grad;

      // Playhead chevron
      const chevH = 6 * dpr;
      const chevW = 4 * dpr;
      const playheadX = ((tick + alpha - ui.viewStart) / range) * w;
      tracksCtx.beginPath();
      tracksCtx.moveTo(playheadX + chevW, h);
      tracksCtx.lineTo(playheadX - chevW, h);
      tracksCtx.lineTo(playheadX, h - chevH);
      tracksCtx.closePath();
      tracksCtx.fill();

      // Playhead line
      tracksCtx.lineWidth = dpr;
      tracksCtx.beginPath();
      tracksCtx.moveTo(playheadX, 0);
      tracksCtx.lineTo(playheadX, h);
      tracksCtx.stroke();

      // Label
      for (let tick = firstTick; tick <= ui.viewEnd; tick += subStep) {
        if (tick < -0.000001) {
          continue;
        }
        const x = ((tick - ui.viewStart) / range) * w;
        const isMajor = Math.abs(tick - Math.round(tick / step) * step) < subStep * 0.1;

        if (isMajor) {
          tracksCtx.fillStyle = "#aaaaaa";
          tracksCtx.fillText(String(Math.round(tick)), x, 2 * dpr);
        }
      }
    }

    render();

    return () => {
      gameCanvasController.destroy();
      tracksCanvasController.destroy();
      inputController.destroy();
      clearInterval(saveInterval);
      cancelAnimationFrame(frameRequest);
    };
  });

  let flushInputBufferInterval: number | undefined;

  function stopAnyPlayback() {
    temp.playing = 0;
    temp.recording = false;
    temp.viewChange = 0;
    if (flushInputBufferInterval !== undefined) clearInterval(flushInputBufferInterval);
  }

  function recordButton(button: HTMLButtonElement) {
    const { abort, signal } = abortSignal();

    button.addEventListener(
      "click",
      () => {
        const { abort, signal } = abortSignal(stopAnyPlayback);

        temp.playing = 1;
        temp.recording = true;

        button.blur();
        gameCanvas.focus();

        flushInputBufferInterval = setInterval(() => {
          inputProxy.peer_id = ui.currentPeerId;
          flushInputBuffer(tick, inputBuffer);
          // send inputs at double the tick rate just to be safe
        }, TICK_RATE);

        button.addEventListener("click", (e) => (e.stopPropagation(), abort()), { signal, capture: true });
        window.addEventListener("keydown", (e) => e.key === "Escape" && abort(), { signal });
      },
      { signal },
    );

    return abort;
  }

  function alphaButton(button: HTMLButtonElement) {
    const { abort, signal } = abortSignal();
    button.addEventListener("click", () => (ui.alphaLock = !ui.alphaLock), { signal });
    return abort;
  }

  function stepButton(step: number) {
    return (button: HTMLElement) => {
      const { abort, signal } = abortSignal();
      button.addEventListener(
        "click",
        () => {
          stopAnyPlayback();
          ui.viewStart += step;
          ui.viewEnd += step;
        },
        { signal },
      );
      return abort;
    };
  }

  function playButton(direction: number) {
    return (button: HTMLButtonElement) => {
      const { abort, signal } = abortSignal();

      button.addEventListener(
        "click",
        () => {
          if (temp.playing === direction) {
            stopAnyPlayback();
          } else {
            temp.playing = direction;
          }
        },
        { signal },
      );

      return abort;
    };
  }

  function markerButton(button: HTMLButtonElement) {
    const { abort, signal } = abortSignal();

    button.addEventListener(
      "click",
      () => {
        if (ui.loopEnd) {
          ui.loopStart = undefined;
          ui.loopEnd = undefined;
        } else if (ui.loopStart) {
          ui.loopEnd = tick;
        } else {
          ui.loopStart = tick;
        }
      },
      { signal },
    );

    return abort;
  }
</script>

<div id="tracks-canvas-container">
  <canvas
    bind:this={tracksCanvas}
    id="tracks-canvas"
    class:panning={temp.tracksCanvasPanning}
    onwheel={(e) => {
      const range = ui.viewEnd - ui.viewStart;
      if (e.shiftKey) {
        temp.viewChange += (range * e.deltaY) / -40000;
      } else {
        const tickUnderMouse = ui.viewStart + 0.5 * range;
        const zoomFactor = e.deltaY > 0 ? 1.3 : 1 / 1.3;
        const newRange = Math.max(4, Math.min(10000, range * zoomFactor));
        ui.viewStart = tickUnderMouse - 0.5 * newRange;
        ui.viewEnd = tickUnderMouse + 0.5 * newRange;
      }
    }}
    // Pan with mouse drag
    onmousedown={(e) => {
      if (e.button === 0) {
        e.preventDefault();

        temp.tracksCanvasPanning = true;
        const { abort, signal } = abortSignal(() => (temp.tracksCanvasPanning = false));

        const drag = {
          x: e.clientX,
          prevX: e.clientX,
          viewStart: ui.viewStart,
          viewEnd: ui.viewEnd,
          width: e.currentTarget.width,
        };

        window.addEventListener(
          "mousemove",
          (e) => {
            const dx = e.clientX - drag.x;
            const tickDelta = (dx / drag.width) * (drag.viewEnd - drag.viewStart);
            ui.viewStart = drag.viewStart - tickDelta;
            ui.viewEnd = drag.viewEnd - tickDelta;
            temp.viewChange = -((e.clientX - drag.prevX) / drag.width) * (drag.viewEnd - drag.viewStart);
            drag.prevX = e.clientX;
          },
          { passive: true, signal },
        );

        window.addEventListener("mouseup", abort);
      }
    }}
  ></canvas>
</div>

<div class="controls">
  {#each { length: 4 } as _, i}
    <button
      style="--color: {PLAYER_COLORS[i]};"
      class:active={ui.currentPeerId === i + 1}
      onclick={() => (ui.currentPeerId = i + 1)}
    >
      P{i + 1}
    </button>
  {/each}

  <div class="divider"></div>

  <button {@attach stepButton(-1)} title="Step back">
    <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
      <rect x="1" y="2" width="2" height="8" />
      <polygon points="11,2 11,10 4,6" />
    </svg>
  </button>
  <button {@attach playButton(-1)} class:active={!temp.recording && temp.playing === -1} title="Rewind">
    <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
      <polygon points="10,1 1,6 10,11" />
    </svg>
  </button>
  <button {@attach recordButton} class:active={temp.recording} title="Record" style="--color: #ef4444 !important">
    <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
      <circle cx="6" cy="6" r="5" />
    </svg>
  </button>
  <button {@attach playButton(1)} class:active={!temp.recording && temp.playing === 1} title="Play">
    <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
      <polygon points="2,1 11,6 2,11" />
    </svg>
  </button>
  <button {@attach stepButton(1)} title="Step forward">
    <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
      <polygon points="1,2 8,6 1,10" />
      <rect x="9" y="2" width="2" height="8" />
    </svg>
  </button>

  <div class="dropdown">
    <div class="dropdown-head">
      <button style="width: 48px;" onclick={() => (ui.playSpeed = 0)}>
        1/{Math.pow(2, -ui.playSpeed)}
      </button>
    </div>
    <div class="dropdown-body">
      <input type="range" step="1" min={-8} max={0} bind:value={ui.playSpeed} />
    </div>
  </div>

  <div class="divider"></div>

  <button {@attach alphaButton} style:font-size="16px" class:active={ui.alphaLock} title="Force alpha=0">α</button>

  <div class="divider"></div>

  <button title="Add loop marker" {@attach markerButton}>
    <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
      <rect x="5" y="1" width="2" height="10" />
      <polygon points="2,1 5,1 5,3" />
      <polygon points="10,1 7,1 7,3" />
      <polygon points="2,11 5,11 5,9" />
      <polygon points="10,11 7,11 7,9" />
    </svg>
  </button>

  <button class:active={ui.loopEnabled} onclick={() => (ui.loopEnabled = !ui.loopEnabled)} title="Loop">
    <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
      <rect x="1" y="1" width="2" height="10" />
      <polygon points="3,1 7,1 3,4" />
      <rect x="15" y="1" width="2" height="10" />
      <polygon points="15,1 11,1 15,4" />
      <rect x="1" y="9" width="16" height="2" />
    </svg>
  </button>

  <div class="divider"></div>

  <button
    onclick={async () => {
      await saveStore.delete();
      location.reload();
    }}
  >
    Reset
  </button>
</div>

<div id="canvas-container" class:recording={temp.recording}>
  <div id="canvas-target">
    <canvas id="canvas" bind:this={gameCanvas}></canvas>
  </div>
  <div id="canvas-overlay" class:panning={temp.canvasOverlayPanning}>
    <pre class="yaml" id="inputs-viewer"></pre>
    <div id="state-viewer">
      <input
        type="text"
        id="state-viewer-input"
        class:invalid={temp.invalidStateQuery}
        placeholder="Type $ to query the state"
      />
      <pre class="yaml" id="state-viewer-output"></pre>
    </div>
  </div>
</div>

<style>
  #canvas-container {
    flex: 1;
    min-height: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    user-select: none;
    position: relative;

    &.recording {
      #canvas-overlay {
        display: none;
      }

      &::before {
        content: "";
        pointer-events: none;
        position: absolute;
        z-index: 10;
        inset: 4px;
        border-radius: 4px;
        border: 2px solid #770000;
      }
    }
  }

  #canvas-target {
    width: 100%;
    height: 100%;
    position: relative;
    &:focus {
      outline: none;
    }
  }

  #canvas {
    position: absolute;
    width: 100%;
    height: 100%;
  }

  #canvas-overlay {
    position: absolute;
    inset: 0;
    cursor: grab;
    &.panning {
      cursor: grabbing;
    }
  }

  #tracks-canvas-container {
    display: block;
    width: 100%;
    height: 50px;
    position: relative;
    background: #111;
    user-select: none;
  }
  #tracks-canvas {
    cursor: grab;
    position: absolute;
    width: 100%;
    height: 100%;
    &.panning {
      cursor: grabbing;
    }
  }

  .controls {
    user-select: none;
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 0.4rem 0.6rem;
    gap: 0.15rem;
    background-color: rgba(17, 17, 17, 0.9);
    border: 1px solid #333;
    border-left: 0;
    border-right: 0;
    z-index: 20;

    .label {
      color: #666;
      font-size: 11px;
      display: flex;
      justify-content: center;
      align-items: center;
    }
  }
  .controls button {
    --color: #fff;

    font-family: monospace;
    font-size: 12px;
    background-color: transparent;
    border: none;
    padding: 0 0.5rem;
    height: 2rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    position: relative;

    color: var(--color);
    z-index: 1;
    opacity: 1;
    min-width: 26px;

    &::before {
      content: "";
      position: absolute;
      inset: 0;
      border-radius: inherit;
      background-color: var(--color);
      opacity: 0;
      z-index: -1;
    }

    &:hover {
      opacity: 1;

      &::before {
        opacity: 0.2;
      }
    }
    &.active {
      font-weight: 700;
      opacity: 1;
      color: #000 !important;
      &::before {
        opacity: 0.9;
      }
    }
    &:active {
      color: #000 !important;
      &::before {
        opacity: 0.7;
      }
    }
    &:focus {
      outline: none;
    }
  }
  .controls select {
    font-family: monospace;
    font-size: 12px;
    background-color: #222;
    color: #ccc;
    border: 1px solid #333;
    border-radius: 3px;
    padding: 0.2rem 0.3rem;
    height: 1.75rem;
    &:focus {
      /* border: 1px solid #777; */
      outline: 1px solid cornflowerblue;
    }
  }
  .controls input[type="range"] {
    -webkit-appearance: none;
    appearance: none;
    height: 4px;
    background: #333;
    border-radius: 2px;
    outline: none;
    cursor: pointer;

    &::-webkit-slider-thumb {
      -webkit-appearance: none;
      width: 10px;
      height: 10px;
      background: #ccc;
      border-radius: 50%;
      border: none;
    }
    &::-moz-range-thumb {
      width: 10px;
      height: 10px;
      background: #ccc;
      border-radius: 50%;
      border: none;
    }
    &:hover {
      background: #444;
      &::-webkit-slider-thumb {
        background: #fff;
      }
      &::-moz-range-thumb {
        background: #fff;
      }
    }
  }

  .divider {
    width: 1px;
    height: 1.5rem;
    margin: 0 5px;
    background-color: #333;
  }

  .dropdown {
    position: relative;
    justify-content: center;
    align-items: center;

    &:hover .dropdown-body {
      visibility: visible;
    }

    .dropdown-body {
      visibility: hidden;
      position: absolute;
      top: 100%;
    }
  }

  #inputs-viewer {
    padding: 0.4rem 0.6rem;
  }

  #inputs-viewer,
  #state-viewer {
    z-index: 20;

    position: absolute;
    top: 8px;
    left: 8px;
    width: 200px;
    font-size: 11px;
    background-color: rgba(17, 17, 17, 0.9);
    border: 1px solid #333;
    border-radius: 8px;
    z-index: 20;
    user-select: text;
    pointer-events: all;
    cursor: auto;
    scrollbar-color: #333 transparent;
  }

  #state-viewer {
    left: unset;
    right: 8px;
    display: flex;
    flex-direction: column;
    width: 250px;
  }

  #state-viewer-input {
    background: none;
    border: none;
    color: white;
    font: inherit;
    padding: 0.4rem 0.6rem;
    font-size: 12px;

    &:active,
    &:focus {
      outline: none;
    }
    &.invalid {
      background-color: #77000050;
    }
  }
  #state-viewer-output {
    border-top: 1px solid #333;
    padding: 0.4rem 0.6rem;
    overflow-y: scroll;
    max-height: 50vh;
  }
</style>
