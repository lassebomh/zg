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
      jsClear() {
        console.clear();
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
    playheadTick: number;
    viewStart: number;
    viewEnd: number;
    currentPeerId: number;
    playSpeed: number;
    playing: number;
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
  import { abortSignal, assert, now } from "./lib/utils.js";
  import { createInputProxy, InputByteLength, inputControl } from "./inputs";
  import { persistent } from "./storage";

  const PLAYER_COLORS = ["#ef4444", "#3b9eed", "#45b358", "#ebc934"];

  const TICK_RATE = 1000 / 60;

  const temp = $state({
    recording: false,
    canvasOverlayPanning: false,
    tracksCanvasPanning: false,
    invalidStateQuery: false,
  });

  let ui = $state<UIState>({
    alphaLock: false,
    playheadTick: 0,
    viewStart: -30,
    viewEnd: 30,
    currentPeerId: 1,
    loopStart: undefined,
    loopEnd: undefined,
    loopEnabled: false,
    playing: 0,
    playSpeed: 0,
    onion: 0,
    cameraX: 0,
    cameraY: 0,
    cameraZoomPosition: 0,
    cameraZoomPositionChange: 0,
    cameraZoom: 1,
    stateQuery: "",
  });

  const tick = $derived(Math.floor(ui.playheadTick));
  const alpha = $derived(ui.alphaLock ? 0 : ui.playheadTick - tick);

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

    let t0 = now();
    function render() {
      let t1 = now();
      let dt = t1 - t0;
      t0 = t1;

      if (ui.loopStart !== undefined && ui.loopEnd !== undefined && ui.loopEnabled) {
        if (ui.playheadTick < ui.loopStart) ui.playheadTick = ui.loopStart;
        if (ui.playheadTick > ui.loopEnd) {
          if (temp.recording) {
            stopAnyPlayback();
            ui.playheadTick = ui.loopEnd;
          } else {
            ui.playheadTick = ui.loopStart;
          }
        }
      }

      if (ui.playing) {
        const tickChange = (dt * ui.playing) / TICK_RATE / Math.pow(2, -ui.playSpeed);
        ui.playheadTick += tickChange;
      }

      if (!ui.loopEnabled) {
        const range = (ui.viewEnd - ui.viewStart) / 2;
        ui.viewStart = ui.playheadTick - range;
        ui.viewEnd = ui.playheadTick + range;
      }

      if (ui.playheadTick < 0) ui.playheadTick = 0;

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

    function renderTracks() {
      const w = tracksWidth;
      const h = tracksHeight;
      const dpr = devicePixelRatio;
      const range = ui.viewEnd - ui.viewStart;

      function tickX(tick: number) {
        return Math.round(((tick - ui.viewStart) / range) * w);
      }

      tracksCtx.fillStyle = "#111";
      tracksCtx.fillRect(0, 0, w, h);

      const playheadX = tickX(tick);
      const playheadX2 = tickX(tick + 1);

      tracksCtx.fillStyle = "#222";
      tracksCtx.fillRect(playheadX, 0, playheadX2 - playheadX, h);

      tracksCtx.textAlign = "center";
      tracksCtx.textBaseline = "top";
      tracksCtx.font = `900 ${10 * dpr}px monospace`;

      // Free playhead
      tracksCtx.strokeStyle = "#888888";
      tracksCtx.lineWidth = dpr;
      tracksCtx.beginPath();
      tracksCtx.moveTo(tickX(ui.playheadTick), 0);
      tracksCtx.lineTo(tickX(ui.playheadTick), h);
      tracksCtx.stroke();

      // Tick marks
      const logStep = 5;
      const step = Math.max(1, Math.pow(logStep, Math.round(Math.log(range / 20) / Math.log(logStep))));
      const subStep = Math.max(1, step / logStep);
      const firstTick = Math.floor(ui.viewStart / subStep) * subStep;

      function isMajor(t: number) {
        return Math.abs(t - Math.round(t / step) * step) < subStep * 0.1;
      }

      for (let tick = firstTick; tick <= ui.viewEnd; tick += subStep) {
        if (tick < -0.000001) {
          continue;
        }
        const x = tickX(tick);

        tracksCtx.strokeStyle = "#666666";
        if (isMajor(tick)) {
          // Major tick line
          tracksCtx.lineWidth = dpr;
          tracksCtx.beginPath();
          tracksCtx.moveTo(x, 0);
          tracksCtx.lineTo(x, h);
          tracksCtx.stroke();
        } else {
          // Minor tick line
          // tracksCtx.setLineDash([2, 2]);
          tracksCtx.lineWidth = dpr;
          tracksCtx.beginPath();
          tracksCtx.moveTo(x, h);
          tracksCtx.lineTo(x, h - h / 8);
          tracksCtx.stroke();
          // tracksCtx.setLineDash([]);
        }
      }

      if (ui.loopStart !== undefined) {
        let startTick = ui.loopStart;
        let endTick = ui.loopEnd ?? ui.playheadTick;

        if (startTick > endTick) {
          [startTick, endTick] = [endTick, startTick];
        }
        tracksCtx.strokeStyle = "cornflowerblue";
        tracksCtx.fillStyle = "cornflowerblue";

        const chevH = 14 * dpr;
        const chevW = 8 * dpr;
        const chevY = h;

        tracksCtx.lineWidth = 2 * dpr;
        tracksCtx.beginPath();
        tracksCtx.moveTo(tickX(startTick) + 1, chevY);
        tracksCtx.lineTo(tickX(endTick) - 1, chevY);
        tracksCtx.stroke();

        if (((endTick - startTick) / range) * w > chevW) {
          //start loop
          {
            const playheadX = tickX(startTick);
            tracksCtx.beginPath();
            tracksCtx.moveTo(playheadX + chevW, chevY);
            tracksCtx.lineTo(playheadX, chevY + chevH / 2);
            tracksCtx.lineTo(playheadX, chevY - chevH / 2);
            tracksCtx.closePath();
            tracksCtx.fill();
          }
          //end loop
          {
            const playheadX = tickX(endTick);
            tracksCtx.beginPath();
            tracksCtx.moveTo(playheadX - chevW, chevY);
            tracksCtx.lineTo(playheadX, chevY + chevH / 2);
            tracksCtx.lineTo(playheadX, chevY - chevH / 2);
            tracksCtx.closePath();
            tracksCtx.fill();
          }
        }
      }

      tracksCtx.fillStyle = "#fff";
      tracksCtx.strokeStyle = "#fff";
      tracksCtx.lineWidth = 2 * dpr;

      // View playhead

      if (!ui.alphaLock) {
        const playheadX = tickX(tick + alpha);
        const chevH = 8 * dpr;
        const chevW = 4 * dpr;
        tracksCtx.beginPath();
        tracksCtx.moveTo(playheadX + chevW, h);
        tracksCtx.lineTo(playheadX - chevW, h);
        tracksCtx.lineTo(playheadX, h - chevH);
        tracksCtx.closePath();
        tracksCtx.fill();
      } else {
        const playheadX = tickX(tick);
        const chevH = 8 * dpr;
        const chevW = 8 * dpr;
        tracksCtx.beginPath();
        tracksCtx.moveTo(playheadX + chevW, h);
        tracksCtx.lineTo(playheadX, h);
        tracksCtx.lineTo(playheadX, h - chevH);
        tracksCtx.closePath();
        tracksCtx.fill();
      }

      for (let t = firstTick; t <= ui.viewEnd; t += subStep) {
        if (t < -0.000001) {
          continue;
        }
        if (isMajor(t)) {
          tracksCtx.fillStyle = "#aaaaaa";
          tracksCtx.fillText(String(Math.round(t)), tickX(t), 8 * dpr);
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
    ui.playing = 0;
    temp.recording = false;
    // if (!ui.loopEnabled){
    //   ui.playheadTick = (ui.viewEnd + ui.viewStart) / 2;
    // }
    if (flushInputBufferInterval !== undefined) clearInterval(flushInputBufferInterval);
  }

  function recordButton(button: HTMLButtonElement) {
    const { abort, signal } = abortSignal();

    button.addEventListener(
      "click",
      () => {
        const { abort, signal } = abortSignal(stopAnyPlayback);

        ui.playing = 1;
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
          ui.playheadTick = Math.max(0, ui.playheadTick + step);
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
          if (ui.playing === direction) {
            stopAnyPlayback();
          } else {
            ui.playing = direction;
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
        if (ui.loopEnd !== undefined) {
          ui.playheadTick = (ui.viewEnd + ui.viewStart) / 2;
          ui.loopStart = undefined;
          ui.loopEnd = undefined;
          ui.loopEnabled = false;
        } else {
          if (ui.loopStart !== undefined) {
            ui.loopEnd = Math.round(ui.playheadTick);
            if (ui.loopEnd < ui.loopStart) {
              [ui.loopEnd, ui.loopStart] = [ui.loopStart, ui.loopEnd];
            }
            ui.loopStart = ui.loopStart;
            ui.loopEnd = ui.loopEnd;
            ui.loopEnabled = true;
            const newRange = (ui.loopEnd - ui.loopStart) * 2;
            const newCenter = (ui.loopEnd + ui.loopStart) / 2;
            ui.viewStart = newCenter - newRange / 2;
            ui.viewEnd = newCenter + newRange / 2;
          } else {
            ui.loopStart = Math.round(ui.playheadTick);
          }
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
    class:loop-mode={ui.loopEnabled}
    class:panning={temp.tracksCanvasPanning}
    onwheel={(e) => {
      const range = ui.viewEnd - ui.viewStart;

      const tickUnderMouse = ui.viewStart + 0.5 * range;
      const zoomFactor = e.deltaY > 0 ? 1.3 : 1 / 1.3;
      const newRange = Math.max(4, Math.min(10000, range * zoomFactor));
      ui.viewStart = tickUnderMouse - 0.5 * newRange;
      ui.viewEnd = tickUnderMouse + 0.5 * newRange;
    }}
    // Pan with mouse drag
    onmousedown={(e) => {
      if (e.button === 0) {
        e.preventDefault();

        temp.tracksCanvasPanning = true;
        const { abort, signal } = abortSignal(() => (temp.tracksCanvasPanning = false));

        let startX = e.clientX;
        let startTick = ui.playheadTick;
        let range = ui.viewEnd - ui.viewStart;
        let width = window.innerWidth;

        if (ui.loopEnabled) {
          startTick = ui.viewStart + (startX / width) * range;
        }

        window.addEventListener(
          "mousemove",
          (e) => {
            const dx = e.clientX - startX;
            let tickChange = (dx / width) * range;
            if (ui.loopEnabled) tickChange *= -1;
            ui.playheadTick = Math.max(0, startTick - tickChange);
            if (ui.loopStart !== undefined && ui.loopEnd !== undefined && ui.loopEnabled) {
              ui.playheadTick = Math.max(ui.loopStart, ui.playheadTick);
              ui.playheadTick = Math.min(ui.loopEnd, ui.playheadTick);
            }
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
  <button {@attach playButton(-1)} class:active={!temp.recording && ui.playing === -1} title="Rewind">
    <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
      <polygon points="10,1 1,6 10,11" />
    </svg>
  </button>
  <button {@attach recordButton} class:active={temp.recording} title="Record" style="--color: #ef4444 !important">
    <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
      <circle cx="6" cy="6" r="5" />
    </svg>
  </button>
  <button {@attach playButton(1)} class:active={!temp.recording && ui.playing === 1} title="Play">
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

  <button {@attach alphaButton} class:active={ui.alphaLock} title="Disable frame interpolation">α=0</button>

  <div class="divider"></div>

  <button
    title="Add loop marker"
    {@attach markerButton}
    class:active={ui.loopStart !== undefined && ui.loopEnd !== undefined}
  >
    <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
      <rect x="5" y="1" width="2" height="10" />
      <polygon points="2,1 5,1 5,3" />
      <polygon points="10,1 7,1 7,3" />
      <polygon points="2,11 5,11 5,9" />
      <polygon points="10,11 7,11 7,9" />
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
    user-select: none;
  }
  #tracks-canvas {
    position: absolute;
    width: 100%;
    height: 100%;

    cursor: grab;
    &.panning {
      cursor: grabbing;
    }
    &.loop-mode {
      cursor: initial !important;
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

    /* .label {
      color: #666;
      font-size: 11px;
      display: flex;
      justify-content: center;
      align-items: center;
    } */
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
  /* .controls select {
    font-family: monospace;
    font-size: 12px;
    background-color: #222;
    color: #ccc;
    border: 1px solid #333;
    border-radius: 3px;
    padding: 0.2rem 0.3rem;
    height: 1.75rem;
    &:focus {
      outline: 1px solid cornflowerblue;
    }
  } */
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
