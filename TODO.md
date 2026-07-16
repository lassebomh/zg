- replace obj parser with https://github.com/ziglibs/wavefront-obj/blob/main/wavefront-obj.zig
  - just copy the code in. replace imports from zlm with local math library
  - check how it handles materials and textures, since that requires loading multiple files.
  - ideally we can parse and process a obj comptime, so we have the processed struct ready. alternative is to just embed like we do now.

- look into bones/rigging/animation libraries.
