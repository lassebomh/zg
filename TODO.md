debugger:

- add inputs viewer
- add state query

general:

- diff state
- in regular play, add shortcut to save the game state as a new debug save file.
- decouple everything in 'game/' from wasm (rendering can be noop)
- move all wasm exports into one central file.
- generate TS bindings to help read/write to zig memory

# solved

the game's viewport is central on the screen

at the bottom a timeline is visible, with a 4 tracks representing the available players.
select a track on its label to control that player. timeline can be controlled by panning or zooming.

# unsolved

playback:

- tick number
- step +- 1 tick
- wind back/forward buttons (hold)
- play (toggle)
- playback speed
- record button (toggle, will play and the speed, recording inputs)

loop:

- set mark a -> set mark b -> clear
- toggle. allows a loop to exist without moving the timeline

viewport:

> onion: onion frames. could be multiple frames, back or forward.
> camera mode: auto, free, source

- frame interpolation mode: auto, custom (value between 0-1)
  > rendering flags: show bounding boxes, global transparency,

inputs:

- a json view showing the inputs of the selected player

state:

- state byte size number
- an expression input to query the state
- the json result of the query
- force rerun current tick
- enable/disable logging

save:

- general save management
- autosave toggle

shortcuts
