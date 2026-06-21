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
    jsGetPeerInputsSize,
    ...unused
  } = instance.exports as any;
  const unusedNames = Object.keys(unused);
  if (unusedNames.length) throw new Error(`Unused export(s): ${unusedNames.join(", ")}`);
</script>

<script lang="ts">
  import { onMount } from "svelte";
  import { attachCanvas } from "./canvas";
  import init from "./wasm/main.wasm?init";
  import { abortSignal } from "./lib/utils.js";
  import { createInputProxy, InputByteLength, inputControl } from "./inputs";

  const PLAYER_COLORS = ["#cc2222", "#2288cc", "#22aa22", "#cccc22"];
  const TICK_RATE = 1000 / 60;

  function getBaseLog(x: number, y: number) {
    return Math.log(y) / Math.log(x);
  }

  let temp = $state({
    recording: false,
    playing: 0,
    canvasOverlayPanning: false,
    tracksCanvasPanning: false,
    invalidStateQuery: false,
  });

  let save = $state({
    viewStart: -30,
    viewEnd: 30,
    viewChange: 0,
    currentPeerId: 1,
    playSpeed: 1,
    onion: 0,
    cameraX: 0,
    cameraY: 0,
    cameraZoomPosition: 0,
    cameraZoomPositionChange: 0,
    cameraZoom: 1,
    stateQuery: "",
  });

  let gameCanvas: HTMLCanvasElement;
  let tracksCanvas: HTMLCanvasElement;

  const inputBuffer = new ArrayBuffer(InputByteLength);
  const inputProxy = createInputProxy(new DataView(inputBuffer));

  let gameWidth = 0;
  let gameHeight = 0;

  function renderTick() {
    const ftick = Math.max(0, (save.viewStart + save.viewEnd) / 2);
    const tick = Math.floor(ftick);
    const alpha = ftick - tick;
    jsRenderTick(ftick, alpha, gameWidth, gameHeight, save.currentPeerId);
  }

  function flushInputBuffer() {
    const ftick = Math.max(0, (save.viewStart + save.viewEnd) / 2);
    const tick = Math.floor(ftick);

    inputProxy.peer_id = save.currentPeerId;
    const inputBytes = new Uint8Array(inputBuffer);
    const memoryBuffer = new Uint8Array(
      (instance.exports.memory as WebAssembly.Memory).buffer,
      jsGetInputBufferPtr(),
      inputBytes.byteLength,
    );
    memoryBuffer.set(inputBytes);
    jsPullInputBuffer(tick);
  }

  onMount(() => {
    const inputController = inputControl(gameCanvas, inputProxy);

    let frameRequest: number;

    let tracksWidth = 0;
    let tracksHeight = 0;

    function render() {
      renderTick?.();
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
        save.viewChange = (dt / TICK_RATE) * temp.playing * save.playSpeed;
      }

      if (!temp.tracksCanvasPanning) {
        save.viewStart += save.viewChange;
        save.viewEnd += save.viewChange;
        save.viewChange *= Math.pow(0.5, dt / 150);
      }

      if (temp.tracksCanvasPanning && temp.playing === 0) {
        save.viewChange *= Math.pow(0.5, dt / 50);
      }

      const viewUnderflow = -Math.min(0, (save.viewEnd + save.viewStart) / 2);
      save.viewEnd += viewUnderflow;
      save.viewStart += viewUnderflow;
      if (viewUnderflow !== 0) {
        save.viewChange = 0;
      }

      const w = tracksWidth;
      const h = tracksHeight;
      const dpr = devicePixelRatio;

      tracksCtx.clearRect(0, 0, w, h);

      const range = save.viewEnd - save.viewStart;
      const trackH = h / 4;

      // Tick marks
      const logStep = 5;
      const step = Math.max(1, Math.pow(logStep, Math.round(getBaseLog(logStep, range / 20))));
      const subStep = Math.max(1, step / logStep);
      const firstTick = Math.floor(save.viewStart / subStep) * subStep;

      for (let tick = firstTick; tick <= save.viewEnd; tick += subStep) {
        if (tick < -0.000001) {
          continue;
        }
        const x = ((tick - save.viewStart) / range) * w;
        const isMajor = Math.abs(tick - Math.round(tick / step) * step) < subStep * 0.1;

        if (isMajor) {
          // Major tick line
          tracksCtx.strokeStyle = "#666666";
          tracksCtx.lineWidth = dpr;
          tracksCtx.beginPath();
          tracksCtx.moveTo(x, 0);
          tracksCtx.lineTo(x, h);
          tracksCtx.stroke();

          // Label
          tracksCtx.fillStyle = "#aaaaaa";
          tracksCtx.fillText(String(Math.round(tick)), x, 2 * dpr);
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

      // Draw track backgrounds
      for (let i = 0; i < 4; i++) {
        const y = i * trackH;
        if (i > 0) {
          tracksCtx.strokeStyle = "#333333";
          tracksCtx.lineWidth = dpr;
          tracksCtx.beginPath();
          tracksCtx.moveTo(0, y);
          tracksCtx.lineTo(w, y);
          tracksCtx.stroke();
        }
      }

      tracksCtx.textAlign = "center";
      tracksCtx.textBaseline = "top";
      tracksCtx.font = `900 ${10 * dpr}px monospace`;

      {
        // Playhead line
        tracksCtx.strokeStyle = "#ffffff";
        tracksCtx.lineWidth = dpr;
        tracksCtx.beginPath();
        tracksCtx.moveTo(w / 2, 0);
        tracksCtx.lineTo(w / 2, h);
        tracksCtx.stroke();
      }

      if (save.onion) {
        tracksCtx.setLineDash([3]);
        tracksCtx.strokeStyle = "#777777";
        tracksCtx.lineWidth = dpr;

        {
          const x = w / 2 - (save.onion / range) * w;
          // Playhead line
          tracksCtx.beginPath();
          tracksCtx.moveTo(x, 0);
          tracksCtx.lineTo(x, h);
          tracksCtx.stroke();
        }
        {
          const x = w / 2 + (save.onion / range) * w;
          // Playhead line
          tracksCtx.beginPath();
          tracksCtx.moveTo(x, 0);
          tracksCtx.lineTo(x, h);
          tracksCtx.stroke();
        }
        tracksCtx.setLineDash([]);
      }

      {
        // Playhead chevron
        const chevH = 6 * dpr;
        const chevW = 6 * dpr;
        tracksCtx.fillStyle = "#ffffff";
        tracksCtx.beginPath();
        tracksCtx.moveTo(w / 2 + chevW, h);
        tracksCtx.lineTo(w / 2 - chevW, h);
        tracksCtx.lineTo(w / 2, h - chevH);
        tracksCtx.closePath();
        tracksCtx.fill();
      }
    }

    render();

    return () => {
      gameCanvasController.destroy();
      tracksCanvasController.destroy();
      inputController.destroy();
      cancelAnimationFrame(frameRequest);
    };
  });
</script>

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

<div class="controls">
  <div class="controls-playback">
    <button
      id="play-reverse"
      title="Play reverse"
      onpointerdown={(e) => {
        temp.playing = -1;
        const { abort, signal } = abortSignal(() => {
          temp.playing = 0;
        });
        e.currentTarget.addEventListener("pointerleave", abort, { signal });
        window.addEventListener("pointerup", abort, { signal });
      }}>◀◀</button
    >
    <button
      id="play"
      title="Play"
      onpointerdown={(e) => {
        temp.playing = 1;
        const { abort, signal } = abortSignal(() => {
          temp.playing = 0;
        });
        e.currentTarget.addEventListener("pointerleave", abort, { signal });
        window.addEventListener("pointerup", abort, { signal });
      }}>▶▶</button
    >
  </div>

  <div class="divider"></div>
  <div class="controls-settings">
    <div class="label">speed</div>
    <select bind:value={save.playSpeed} class="dropdown-menu-inner">
      {#each { length: 7 } as _, i}
        {@const value = Math.pow(2, i)}
        <option value={1 / value}>1/{value}</option>
      {/each}
    </select>
    <div class="label">onion</div>
    <input type="number" id="onion" value="0" min="0" />
  </div>
  <div class="divider"></div>
  <button
    class="record-btn"
    class:recording={temp.recording}
    id="record"
    onclick={(e) => {
      temp.playing = 1;
      temp.recording = true;
      const flushInputBufferInterval = setInterval(() => {
        flushInputBuffer?.();
        // send inputs at double the tick rate just to be safe
      }, TICK_RATE);
      const { abort, signal } = abortSignal(() => {
        temp.playing = 0;
        temp.recording = false;
        clearInterval(flushInputBufferInterval);
      });
      const button = e.currentTarget;
      button.addEventListener(
        "click",
        (e) => {
          e.stopPropagation();
          abort();
          button.blur();
          gameCanvas.focus();
        },
        { signal, capture: true },
      );
      window.addEventListener("keydown", (e) => e.key === "Escape" && abort(), { signal, capture: true });
    }}>⏺ REC</button
  >
</div>

<div class="tracks">
  <div class="track-labels">
    {#each { length: 4 } as _, i}
      <button
        class="track-label"
        style="--track-color: {PLAYER_COLORS[i]};"
        class:selected={save.currentPeerId === i + 1}
        onclick={() => (save.currentPeerId = i + 1)}
      >
        Player {i + 1}
      </button>
    {/each}
  </div>
  <div id="tracks-canvas-container">
    <canvas
      bind:this={tracksCanvas}
      id="tracks-canvas"
      class:panning={temp.tracksCanvasPanning}
      onwheel={(e) => {
        const range = save.viewEnd - save.viewStart;
        if (e.shiftKey) {
          save.viewChange += (range * e.deltaY) / -60000;
        } else {
          const tickUnderMouse = save.viewStart + 0.5 * range;
          const zoomFactor = e.deltaY > 0 ? 1.1 : 1 / 1.1;
          const newRange = Math.max(4, Math.min(10000, range * zoomFactor));
          save.viewStart = tickUnderMouse - 0.5 * newRange;
          save.viewEnd = tickUnderMouse + 0.5 * newRange;
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
            viewStart: save.viewStart,
            viewEnd: save.viewEnd,
            width: e.currentTarget.width,
          };

          window.addEventListener(
            "mousemove",
            (e) => {
              const dx = e.clientX - drag.x;
              const tickDelta = (dx / drag.width) * (drag.viewEnd - drag.viewStart);
              save.viewStart = drag.viewStart - tickDelta;
              save.viewEnd = drag.viewEnd - tickDelta;
              save.viewChange = -((e.clientX - drag.prevX) / drag.width) * (drag.viewEnd - drag.viewStart);
              drag.prevX = e.clientX;
            },
            { passive: true, signal },
          );

          window.addEventListener("mouseup", abort);
        }
      }}
    ></canvas>
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

  /* Tracks bar */
  .tracks {
    flex-shrink: 0;
    display: flex;
    height: 96px;
    border-top: 1px solid #333;
    background: #111;
    user-select: none;
  }
  .track-labels {
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
  }
  .track-label {
    border: none;
    padding: 0 1em;
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    color: white;
    cursor: pointer;
    user-select: none;
    border-bottom: 1px solid #222;
    background-color: color-mix(in srgb, var(--track-color) 20%, transparent);

    &:hover {
      background-color: color-mix(in srgb, var(--track-color) 40%, transparent);
    }
    &.selected {
      font-weight: bold;
      background-color: color-mix(in srgb, var(--track-color) 100%, transparent);
    }
    &:active {
      background-color: color-mix(in srgb, var(--track-color) 60%, transparent);
    }
  }
  .track-label:last-child {
    border-bottom: none;
  }
  #tracks-canvas-container {
    flex: 1;
    min-width: 0;
    display: block;
    width: 100%;
    height: 100%;
    position: relative;
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
    position: absolute;
    bottom: calc(96px + 0.75rem);
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    padding: 0.4rem 0.6rem;
    gap: 0.5rem;
    background-color: rgba(17, 17, 17, 0.9);
    border: 1px solid #333;
    border-radius: 8px;
    z-index: 20;
  }
  .controls-playback {
    display: flex;
    align-items: center;
    gap: 0.15rem;
  }
  .controls button {
    font-family: monospace;
    font-size: 14px;
    background-color: transparent;
    color: #ccc;
    border: none;
    padding: 0 0.5rem;
    height: 2rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;

    &:focus {
      outline: none;
    }
  }
  .controls button:hover {
    background-color: #333;
    color: #fff;
  }
  .controls-settings {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .controls-settings .label {
    color: #666;
    font-size: 11px;
  }
  .controls select,
  .controls input[type="number"] {
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
  .controls input[type="number"] {
    width: 3.5rem;
  }
  .divider {
    width: 1px;
    height: 1.5rem;
    background-color: #333;
  }
  .record-btn {
    color: #c44 !important;
    font-size: 12px !important;
    width: auto !important;
    padding: 0 0.5rem !important;
    gap: 0.3rem;
    &:hover {
      background-color: #c443 !important;
    }
  }
  .record-btn.recording {
    background-color: #c44 !important;
    color: #000 !important;
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
