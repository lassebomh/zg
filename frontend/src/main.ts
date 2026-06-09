const wasm = await WebAssembly.instantiateStreaming(fetch("./main.wasm"), {
  env: {
    /**
     * @param {number} num
     */
    jsLogf32(num: number) {
      console.warn(num);
    },
    jsLogu8(num: number) {
      console.warn(num);
    },
  },
});

const { memory, main, frame, getInputPtr, getInputLen, getOutputPtr, getOutputLen, getDrawCommandLen, ...unused } = wasm
  .instance.exports as any;

const buffer = (memory as WebAssembly.Memory).buffer;

const unusedNames = Object.keys(unused);
if (unusedNames.length) throw new Error(`Unused export(s): ${unusedNames.join(", ")}`);

const input = new Uint8Array(buffer, getInputPtr(), getInputLen());
const output = new Uint8Array(buffer, getOutputPtr(), getOutputLen());

main();

// console.log(input);

const commands = frame(1, 1024, 1024);

console.log(output);

export {};
