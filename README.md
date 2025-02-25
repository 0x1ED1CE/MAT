# Model Animation Texture
![LICENSE](https://img.shields.io/badge/LICENSE-MIT-green.svg)

MAT is a simple yet efficient 3D format intended for embedded applications.

<img src="/screenshots/miku.gif?raw=true">

## Features
- Single-file decoding library
- Big-endian binary format for better portability
- Flat data structure for easy parsing
- Variable fixed point encoding
- Supports multiple meshes and animations in a single file
- Supports vertex attributes for normals, colors, uv and skinning
- Supports custom attributes and metadata

## Limitations
- Only one bone per vertex allowed
- No bone hierarchy
- No interpolation

## How to use
- [mat.h](mat.h) single-file decoding library
- [debug.c](debug.c) test code that prints out the attributes
- [obj2mat.lua](obj2mat.lua) tool for converting .obj files to .mat
- [dae2mat.lua](dae2mat.lua) tool for converting .dae files to .mat

## License
This software is free to use. You can modify it and redistribute it under the terms of the 
MIT license. Check [LICENSE](LICENSE) for further details.
