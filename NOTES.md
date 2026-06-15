whats the point of sending individual commands? Why not just capture a full input frame?
rollback should track its input dependency
sliding rollback? NEATO!

"debug" / "overlay" render functions!
maybe different render functions for global/spectating/debugging where the camera is global

should zig be accountable for networking?

- opt 1: no, but it handles the the timeline
  - rendering and inputs are controlled from the outside.
  - problem: desync cannot be detected, unless it has methods for import/exporting state.
  - which it should probably do anyways. Nice for ergonomics and testing.
- opt 2: handle communication
  issue: will need a way of communicating between clients IN ZIG!
  unless its one way message passing, it could become

the boundary is probably best where js needs control, e.g.

js controls last safe tick + merged inputs + recent inputs?
