// @ts-nocheck

const wasm = await WebAssembly.instantiateStreaming(fetch("./wasm/main.wasm"), {
  env: {
    /**
     * @param {number} num
     */
    jsLogf32(num) {
      console.warn(num);
    },
    jsLogu8(num) {
      console.warn(num);
    },
  },
});

const { memory, main, frame, getInputPtr, getInputLen, getOutputPtr, getOutputLen, getDrawCommandLen, ...unused } =
  wasm.instance.exports;

const unusedNames = Object.keys(unused);
if (unusedNames.length) throw new Error(`Unused export(s): ${unusedNames.join(", ")}`);

const input = new Uint8Array(memory.buffer, getInputPtr(), getInputLen());
const output = new Uint8Array(memory.buffer, getOutputPtr(), getOutputLen());

console.log(getDrawCommandLen());

main();

// console.log(input);

const commands = frame(1, 1024, 1024);

console.log(output);
