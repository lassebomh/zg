debugger:

- persist inputs
- add inputs viewer
- add state query

general:

- decouple everything in 'game/' from wasm (rendering can be noop)
- move all wasm exports into one central file.
- generate TS bindings to help read/write to zig memory
