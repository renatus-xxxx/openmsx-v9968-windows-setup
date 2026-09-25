[日本語](SHALLOW.ja.md)

# Scene 7 — Shallow Water

Press **7** in the normal demo. **0** returns to the seven-scene automatic sequence.

Small angular stones are lit by caustics that widen toward the foreground, with translucent reflection streaks above them. Floor and light share a fixed perspective projection. [Clearwater](https://github.com/Aureliengmz/clearwater) inspired the appearance; code and assets are independently created.

## Light width and shading

Python inverse-projects each screen position onto the floor:

```text
d = y + 84
X = 160 * (x - 128) / d
Z = 28800 / d
```

Travelling waves deform these ground coordinates. Distance to a Voronoi boundary produces a narrow light core and a softer shoulder. Unlike a one-pixel screen-space boundary detector, a world-space width projects to thin distant lines and broader foreground lines. Width and strength vary with the waves. A 2×2 subpixel average is quantized to four light levels.

The sixteen background colours represent four material tones times four illumination levels. Floor indices are 0–3; masks use 0/4/8/12. LMMM OR selects a designed shade, not physical addition or alpha blending. Reducing material tones to four pays for wider, graded light. The foreground floor is brighter and the distance more subdued; this is an artistic approximation, not water-depth or Fresnel simulation.

Light masks are 256×160 with 128 shapes, selected every four ticks: at 60 Hz, at most 15 shapes/s and an approximately 8.53-second cycle. Slow rendering skips intermediate shapes. Refraction uses a separate 128-phase clock. Equal adjacent row displacements are merged into HMMM bands. This is not complete-frame video playback.

## Surface reflections: Sprite mode3

Sixty-two Sprite mode3 planes comprise twenty bright glints, ten low-priority soft glare shoulders, and eight four-segment reflection ribbons. The glints overlap the shoulders, but only one sprite wins at each pixel. This approximates optical bloom; it is not additive light. Four-level transparency and palette set 1 preserve the bottom beneath the softer reflections.

Sprite priority is resolved before RGB5 blending with the background. Overlapping sprites do not add together. Generation checks the 16-planes-per-scanline limit and header exclusion. The pinned emulator outputs a sprite one line below its attribute Y; screen checks account for this.

Enable SP3 before refreshing R5/R6. The pinned emulator may retain old VRAM table masks on an SP3-only transition, so the table registers are forced through another value while sprites are disabled. Leaving the scene disables sprites and restores the R20 value selected at boot.

## Rendering and VRAM

SCREEN 5, 256×192, sixteen RGB5 background colours, active water area 240×160. The separate sprite palette and alpha blending mean final output is not limited to sixteen colours.

1. Update the light cache to the time-selected shape.
2. Restore the page-3 floor to the back page and refract HMMM bands.
3. Apply the light with LMMM OR.
4. Draw the fixed header; wait for CE and vertical sync, then flip pages.
5. Update the palette and 504 bytes of sprite attributes.

| VRAM range | Use |
|---|---|
| 0x00000–0x0FFFF | Front/back images |
| 0x10000–0x14FFF | 20 KiB light mask |
| 0x15000–0x15FFF | Twelve ribbon patterns, four shoulder slots, twelve glint profiles and blank slots, 4 KiB |
| 0x17E00–0x17FFF | 512-byte sprite attribute area |
| 0x18000–0x1DFFF | 24 KiB floor |
| 0x1E000–0x1FFFF | Scene headers |

All addresses remain below 128 KiB. Patterns upload only on entry; normal frames update attributes.

## ROM and streaming

8 MiB ASCII16-X, with 7,929,856 allocated bytes. Sixteen full key masks (one every eight phases) occupy 512 KiB. Direct one-, two- and three-phase delta tables occupy 2 MiB each. Any shape can be reconstructed exactly from its nearest key mask using at most three deltas. All 128 shapes remain available.

Advances of up to nine phases use at most three direct deltas; larger time jumps start from a key mask. This avoids replaying every skipped shape. Each record is split at the VRAM 16 KiB boundary, and R14 is reset before each section. Two/three-phase records hold both variable-length sections in a single ROM bank, with a leading offset locating the second section.

ASCII16-X has a 12-bit bank register, but the pinned openMSX uses an 8 MiB flash model. A 16 MiB prototype failed the boot check and was rejected. The signature stays in bank 511. Existing Scene 1–6 assets and benchmark ROMs are preserved.

## Regeneration and checks

Python, Pillow and NumPy are required for generation and pixel checks, not for running the demo.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File build.ps1 -Z88dk "<z88dk root>"
python verify-shallow.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File test-shallow.ps1 -Runtime "<isolated runtime>"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File test.ps1 -Runtime "<isolated runtime>"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File test.ps1 -Runtime "<isolated runtime>" -CaptureScript measure-shallow.tcl
```

Equivalent C-language streaming implementations are selected with `build.ps1 -CStream -ProfileFilter internal`, followed by `test-shallow.ps1 -CStream`.

Checks individually cover all 128 light shapes and 128 refraction phases, time jumps, cache reconstruction, sprite attributes over 128 phases and resident patterns. They are not an exhaustive Cartesian-product test. At selected frozen phases, RGB blending is checked against separate opaque/background/translucent screenshots using RGB5 arithmetic. This revision has not been tested on physical hardware/FPGA.

## Primary references

- [Sprite mode3 description](https://note.com/thara1129/n/n810be44fba3e)
- [Pinned openMSX sprite attribute implementation](https://github.com/buppu3/openMSX/blob/14215c7395649c3981fcc56733d0720acc11c1fd/src/video/SpriteChecker.cc)
- [Pinned openMSX transparency arithmetic](https://github.com/buppu3/openMSX/blob/14215c7395649c3981fcc56733d0720acc11c1fd/src/video/SpriteConverter.hh)
- [ASCII16-X flash model](https://github.com/buppu3/openMSX/blob/14215c7395649c3981fcc56733d0720acc11c1fd/src/memory/RomAscii16X.cc)

Checked 2026-09-25. These sources informed an independent implementation; their code was not copied.

## Reflection ribbons and distant attenuation

A shared `water_warp()` produces the texture-coordinate deformation used by the caustics. Reflection anchors follow its inverse through `follow_water()`: this is essential because adding a texture displacement would move visible features in the wrong direction. Surface-normal-like slopes are finite differences of a height proxy built from that same field; a fixed-view Blinn-Phong-style response controls thickness and transparency.

This couples the motion, phase and intensity modulation, but it is an artistic approximation, not ray-traced reflection/refraction or physical caustic transport. The existing bottom images remain unchanged. Reflection brightness need not match the brightness of the floor immediately beneath it. Runtime only selects precomputed attributes; Newton iteration and shading run in Python.

Caustic strength uses `0.12 + 0.88*d*d*(3-2*d)`, where screen depth d runs from zero in the distance to one in the foreground. Attenuation is applied before four-level quantization, rather than just thinning the lines. Distant light becomes subdued while foreground width and brightness remain. Finite colour levels still limit smoothness.

Attributes use 512 bytes per phase, or 64 KiB for 128 phases. Each frame uploads 504 bytes for 62 sprites and the terminator. Patterns remain 4 KiB and the VRAM SAT remains 512 bytes.

## Central sun-glitter path

Twenty short, skewed glints are staggered along a narrow central path. Their lengths, thicknesses, fade profiles and 0/25/50/75% transparency vary with the shared wave field. A central depth envelope favours the middle of the water surface; outer glints fade rather than forming equally bright rungs. The white core reaches RGB5 (31,31,31). Ten slanted soft shoulders remain behind the core and are hidden when their energy is low.

The renderer selects the highest-priority nonzero sprite pixel before blending it with the background. Transparent sprite pixels reveal the next sprite; translucent pixels do not blend with another sprite below them. Thus the core and shoulder must be designed together. More overlapping sprites alone cannot exceed maximum white or produce HDR.

Python performs wave inversion, finite-difference slope calculation and fixed-view specular shaping. This is a physically inspired approximation based on a shared height proxy, not a fluid simulation, a full microfacet model or a simulation of light rays forming the bottom caustics. Floor images and caustic masks are unchanged. No random numbers are generated at runtime.

The scene stays within 62 planes, at most eleven per scanline, 128 KiB VRAM and 8 MiB ROM. Pixel and four-level-alpha quantization remain visible. Denser highlights and brighter shoulders improve local brightness, but also hide some bottom detail. Hardware/FPGA behaviour is not verified.

The 504-byte attribute upload uses two OTIR blocks (256 + 248 bytes). `-CStream` builds the equivalent C-language loop for output comparison. This shortens attribute transfer; it does not speed up the VDP commands themselves.

## Measured performance

Pinned emulator; 5-second warm-up, 15-second sample, three independent launches per CPU. Recording is separate. These are emulator results, not FPGA measurements.

| CPU | Before FPS | After FPS | Frames / 15 s |
|---|---:|---:|---|
| Z80 | 8.73 | 9.00 | 135 / 135 / 135 |
| R800 | 11.20 | 11.20 | 168 / 168 / 168 |
