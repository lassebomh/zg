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

//

everything is in world coordinates.
update state returns a camera.

# important

might solve issue with sun:

- putting a pixel outside the screen will just slide it to the edge of the screen?

- caching! Store a 'touched' value?

- downscaled height maps could allow for fast collision checks

# update + render + camera?

---

maybe do an iterative light propagation:

- every point with a light grows

---

# MONEYYYY: flatten effects: make waves in the height map. could be a cool posteffect.

---

lighting

color
height
occlusive_height

The last param to drawPixel determines if this pixel is an occluder. This is useful for a doorway, where you want light to pass through but it overlays a character walking though.
When a pixel is drawn, this is what happens:

if its occluding and its z is greater than occlusive_height[x, y], set the value to z.
if z is greater than height[x, y], set the value to z AND update color.

The shader will for every light source walk from its xy and set its z to “height[x,y]”, walk to the light source
