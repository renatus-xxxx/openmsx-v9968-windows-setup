[日本語](README.ja.md)

# V9968 TECH DEMO

The Release ZIP also includes `V9968-TECH-DEMO-external-0x88.rom` for the external HRA! V9968 cartridge. Use the canonical `V9968-TECH-DEMO.rom` for openMSX. See [profiles and hardware test scope](DEVELOPMENT.md).

A C technical demo for V9968-enabled openMSX, supplied as a 1 MiB ASCII16 ROM. Six scenes show a solid, perspective-style floor, underwater distortion, large panels and feedback, repeating in roughly 90 seconds.

After completing the corresponding setup at the repository root, run `launch-v9968-tech-demo-fsa1gt.bat` (FS-A1GT / R800) or `launch-v9968-tech-demo-cbios.bat` (C-BIOS / Z80). The ROM is `V9968-TECH-DEMO.rom`, using MSX 8x8 font. Normal launch requires neither z88dk nor Python.

![Underwater distortion](water-preview.gif)

The water GIF and raster below show the default octahedron generated from OBJ input.

![Default octahedron OBJ raster](assets/mesh-source-preview.png)

| Key | Action |
|---|---|
| 1–6 | Select a scene |
| 0 | Return to automatic playback |
| W | Toggle water distortion; compare it in scene 3 |
| Esc | Stop picture and music; close and relaunch to replay |

| Scene | Presentation |
|---|---|
| 1 REACTOR | Precomputed shaded OBJ-mesh rotation/projection (the supplied default is an octahedron), rendered as VDP spans |
| 2 FLIGHT DECK | LRMM source/scale changes per two-pixel strip, with 3D orbits |
| 3 UNDERTOW | Render submerged ruins and an animated solid, capture to VRAM and resample with vertical waves and gentle horizontal motion of up to two pixels each way |
| 4 VORTEX | LRMM rotation and zoom of a detailed large grid panel |
| 5 RESONANCE | Metallic sphere, 3D orbits and 12 depth-ordered fragments |
| 6 AFTERGLOW | Opens on a bare frame with no header. The solid is drawn flat white into a held page that one full-screen LMMV with the AND operation dims by exactly one step each frame, under a greyscale palette where brightness is the number of bits set in the colour index, so the trail fades evenly to black. The held page is also magnified slightly each frame, which walks the fading copies out from under the solid instead of leaving them hidden beneath it. After three seconds the header appears and the scene continues into recursive framebuffer feedback, where the previous frame stays in VRAM, is shifted with HMMM or transformed with LRMM, combined with the current LMMV-rendered solid, and captured back as the next history frame |

Projection, OBJ rasterization, solid scanlines and deformation parameters are precomputed into ROM. Orbits, fragments and water have 256 steps; the shared OBJ mesh and floor have 128. Water is a screen-refraction effect that vertically resamples horizontal strips, with a four-pixel amplitude and 64-pixel spatial period. Vertical source positions are clamped; horizontal motion is limited to two pixels each way, with outermost pixels repeated to fill the edges. The picture behind the header waves with everything else; the title and scene number are drawn over it afterwards and stay put. Scene 3 animates the solid with the same pose table and clock as Scene 1, applying distortion to a freshly rendered image each frame.

The header of every scene is one transparent blit of a strip that already carries a one-dot black drop shadow behind the text, drawn straight onto the finished picture, so it stays readable over any background.

### Replacing the 3D mesh

`generate-megarom.py` now accepts a geometry-only Wavefront OBJ. The default source is `assets/octahedron.obj`; Scene 1, Scene 3 and Scene 6 share that MESH table, so replacing it changes all three scenes. The generator recenters and normalizes the model, renders 128 poses with an offline Z-buffer, flat-shades the final raster, and emits exactly the same 4096-byte-per-frame VDP command format used by the runtime.

```powershell
python generate-megarom.py --mesh-obj assets/torus.obj --mesh-radius 74
powershell.exe -NoProfile -ExecutionPolicy Bypass -File build.ps1 -Z88dk "C:\z88dk" -MeshObj "C:\models\model.obj" -MeshRadius 74
```

OBJ vertex positions and polygon faces are used; texture coordinates, supplied normals and materials are ignored. Faces are fan-triangulated, so non-convex polygons should be triangulated in the source file. The fixed MESH record can hold at most 371 vertically merged rectangles per pose; an OBJ that is too detailed fails generation with the offending frame/count instead of corrupting the next ROM asset. Reducing polygon detail or `--mesh-radius` can bring a model under the limit.

Rendering uses SCREEN 5 at 256×192 with 16 colors, five-bit RGB components, HS and LRMM. Water strip transfers use HMMM: the technique is not exclusive to V9968, but benefits from its accelerated commands.

The current source tree targets pinned `buppu3/openMSX 14215c7`; earlier measurements on d884c4b remain historical records. See the [emulator update record](../../docs/emulator-update-20260924.md). The launcher specifies `-romtype ASCII16`; select that type when opening the ROM separately. All bank numbers stay below 256, so the same ROM also runs unchanged on ASCII16-X hardware. Physical hardware and other emulators remain untested.

The original three-voice PSG score is included. Timing results for earlier builds are not performance measurements of 0.7.2.

See [development and verification](DEVELOPMENT.md) for builds, precomputation, VRAM layout and results.

## Acknowledgments

V9968 TECH DEMO uses **MSX 8x8 font** by **1re1** for its title and scene labels. Thank you to the author for making this font available. See [sources, terms and conversion](third-party/fonts/README.md).

Scene 3 preserves its pixels while reducing VDP transfers and command setup. [Optimization results](../scene3-benchmark/OPTIMIZATION.md).

## OBJ compatibility and default shape

Wavefront OBJ input is supported at build time. The original octahedron shape (`assets/octahedron.obj`) is the default; `assets/torus.obj` is an optional example. `-MeshObj` / `--mesh-obj` still accept external files. Scene 1, 3 and 6 share the mesh; no runtime OBJ parser is added.

The new default is not pixel-identical to 0.7.1. The default radius is 88, preserving the original octahedron vertex scale. The optional torus must explicitly use radius 74. It also uses subpixel projection, pixel-centre Z-buffer rasterization and normal-based two-sided shading (indices 8/10/12), instead of rounded polygon painting and animated face-index shading (8–12). All 128 frames differ. Rotation timing, camera formula and runtime effects are unchanged. Concave polygons are not generally supported by fan triangulation; triangulate them before import. Materials and supplied normals are ignored.

The shipped benchmark ROMs and FPS/PDF records remain historical 0.7.1 artifacts. Rebuilding produces the current OBJ workload; do not attach the old measurements to that ROM. [OBJ build and validation results](obj-verification.json).

The torus example uses up to 356 of 371 rectangles per pose (15 left); adding detail or increasing its radius can exceed capacity. Relative OBJ paths are resolved against the current working directory first, then the demo directory. Use an absolute path to select an unambiguous external file. Omitted `-MeshRadius` uses the generator default (88); explicit values still override it. OBJ backslash line continuations are supported; non-finite vertex coordinates are rejected with a line number.
