debugger:

- a json view showing the inputs of the selected player

- state byte size number
- an expression input to query the state
- the json result of the query
- force rerun current tick
- enable/disable logging

- general save management
- autosave toggle

- camera mode: auto, free, source
- rendering flags: show bounding boxes, global transparency,

general:

- diff state
- in regular play, add shortcut to save the game state as a new debug save file.
- decouple everything in 'game/' from wasm (rendering can be noop)
- move all wasm exports into one central file.
- generate TS bindings to help read/write to zig memory
