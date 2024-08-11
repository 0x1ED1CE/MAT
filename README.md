# Model Animation Texture
![LICENSE](https://img.shields.io/badge/LICENSE-MIT-green.svg)

MAT is a simple yet efficient 3D format intended for embedded applications.

## Features
- Single-file decoding library
- Big-endian binary format for better portability
- Flat data structure for easy parsing
- Variable fixed point encoding
- Supports multiple meshes in a single file
- Supports vertex attributes for normals, texture coordinates and skinning
- Supports custom attributes and metadata

## How to use
- [mat.h](mat.h) single-file decoding library
- [debug.c](debug.c) test code that prints out the attributes
- [obj2mat.lua](obj2mat.lua) tool for converting .obj files to .mat

## TODO
- Animation specification
- Collada conversion tool
- API documentation

## Why?

You may be asking why I made this when there are already many other formats out there. MAT is not intended to displace those. I created this because I needed a highly efficient runtime format with specific requirements for my [ICE](https://github.com/0x1ED1CE/ICE) game engine, which others could not fulfill.

## License
This software is free to use. You can modify it and redistribute it under the terms of the 
MIT license. Check [LICENSE](LICENSE) for further details.
