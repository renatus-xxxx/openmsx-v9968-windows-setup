[日本語](DEVELOPMENT.ja.md)

# Development and verification

[Demo guide](README.md)

## Build

Python 3 with Pillow and z88dk are required for rebuilding, not for normal setup or launch. Run in this directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File build.ps1 -Z88dk "C:\z88dk"
```

Pass your actual z88dk location. The build always runs `generate-fonts.py` and `generate-megarom.py`, then compiles C with zsdcc. It checks the fixed bank fits 16 KiB, BSS stays below CF00 and the final ROM is 1 MiB. Outputs are `build/V9968-TECH-DEMO.rom` and the distribution copy `V9968-TECH-DEMO.rom`. Warning 85 for assembly-consumed arguments and PSG optimizer warning 110 remain.

## Assets and rendering

Editable sources are `assets/chamber-source.png` and `assets/seabed-source.png`. `python convert-assets.py` generates the 16-color images. [MSX 8x8 font](third-party/fonts/README.md) is converted and composed into the header strips. `assets/PROMPT.txt` records image generation settings.

SCREEN 5 uses 256×192 with 16 colors, the extended palette, HS and LRMM. Pages 0/1 alternate drawing/display; page 3 stores backgrounds and the six header strips; page 2 holds textures or the water source.

Rotation/projection, solid spans, floor/panel/water parameters are precomputed. Fixed code uses 4000–7FFF; 8000–BFFF is the data window for 64 ASCII16 banks, selected through the register at 7000H. Because every bank number stays below 256, the write is plain ASCII16 and behaves identically on ASCII16-X hardware. The interrupt never switches banks. CF00 onward holds telemetry; D000–D100 and D1D1–D1D3 are reserved for IM2.

Stride-addressed assets emit a `FRAMES_<NAME>` constant into `bank-layout.h`. The runtime masks frame indices with `FRAMES_<NAME>-1`, so a change to the generated frame count cannot silently read into the next asset. The generator asserts that each count is a power of two of at most 256.

## The header

Every scene draws its header onto the picture with a drop shadow, in one transparent LMMM from a 186x9 strip that already holds the shadow behind the text. The title used to be baked into the background images and arrive with the copy that begins each frame, which meant Scene 6, whose picture has nothing to do with those images, had to restore a strip of one just to carry its header. Now nothing is restored behind the header, and the shadow also makes the title legible where the city texture behind it is busy.

The shadow is index 1, not 0. On this VDP transparency means "colour 0 is not written", and 0 is black, so a black glyph is exactly what a transparent blit throws away: black cannot be written, only cleared to. Index 1 is (1,2,3) of 31, which is black to the eye. A true black shadow would mean an opaque LMMM with the AND operation from an inverse mask, 15 everywhere except the glyphs, which clears the glyph shape and leaves every other destination pixel alone. That works, and was the first version, but it costs a second blit per string. Compositing the shadow into the strip instead, and putting the label and the title in the same strip, takes the header from four blits to one.

The six strips are 54 of the 64 VRAM rows free above the background. LABELS keeps its bank because the Scene 3 benchmark overwrites that bank with a font atlas, although the demo no longer uploads it. Nothing is restored behind a header in any scene now, including Scene 3: its header band used to stand still while the rest of the picture waved, which was only necessary while the title was baked into the background image and would otherwise have rippled as a ghost. The band is part of the distortion now and the text sits on top of it. Measured per scene against a build whose header is the single opaque blit it used to be, the composited strip costs at most 0.3% of the frame rate; the four-blit version cost up to 3%.

## Scene 6 feedback

Scene 6 has two halves joined by a header reveal. It borrows VRAM page 2, the page that otherwise holds textures and the Scene 3 water capture; it clears the page on entry and calls `textures_load()` on exit, so no extra page is needed.

Timing comes from the tick recorded when the scene is entered, not from the free-running clock, so the opening always plays from the start even when the scene is selected by hand. The first 180 ticks are the decay trail, drawn with no header, scene label or top rule. From tick 180 the header appears and stays, and the four feedback phases run 180 ticks each; while the scene is held by hand those four phases repeat and the header stays up. The hidden header is deliberate staging, not a regression: the second half draws exactly the HUD every other scene draws.

The two halves share page 2, and the transition does not clear it, so the trail accumulated by the opening becomes the first history frame of the feedback half and the picture joins with no visible cut.

The opening fades by colour: one full-screen LMMV with the AND operation clears bits of every index on the accumulation page. Because the opening carries no header, scene label or top rule, all sixteen palette entries are free there, so brightness is defined as the population count of the colour index. Clearing any one bit then steps a pixel exactly one level darker whatever it started from. `palette_glow()` installs that greyscale popcount palette for the opening only, and the four masks `0x0e 0x0d 0x0b 0x07` clear one bit each and all four between them, so a pixel loses exactly one level per frame regardless of phase. Clearing bits can only lower the population count, so the trail can never brighten. The next ordinary `palette()` call rewrites all sixteen entries, so nothing leaks into the second half.

The solid is drawn flat at index 15, the top of that ramp, and fades 15 to 14 to 12 to 8 to 0 in four even steps. The held page is also magnified about 5% per frame before the decay, so the fading copies walk out from under the solid instead of being redrawn over: the solid covers almost the same pixels each frame, and a trail that stays put is hidden beneath it. That costs a clear and an LRMM per frame, which measured 18.2 to 16.0 frames per second in the opening. `stream_spans_glow()` is `stream_spans()` with the colour byte of each LMMV packet replaced by 15 as the packet is streamed out, which leaves the shared MESH span data and Scene 1 untouched; a second copy shaded differently would have cost half the ROM. Substituting the colour also removes a real defect. The shading ramp starts at 8, binary `1000`, whose only set bit is the top one. Three of the four masks leave it exactly where it is and the fourth clears it to the background, so an index-8 pixel cannot fade gradually at all: depending on where in the cycle it was written it either held full brightness for up to three frames or vanished at once, and roughly half the solid was drawn at that index.

The free palette is what makes this work, and it is also why the effect is confined to the opening. Measured on the header strip, 86% of its pixels use indices 0-7, so a popcount palette and a correctly coloured title cannot coexist in sixteen colours. From the reveal onward Scene 6 shares the normal palette and the same HUD as every other scene.

Two details make the reveal itself clean. The trail the opening hands over is written in popcount indices, and 13, 14 and 15 are white, cyan and orange in the ordinary palette, so the feedback half would recycle those three colours for many generations. One AND clearing bit 2, applied to page 2 on the first frame of the second half, confines every index the opening can produce to the grey mesh band at 8-11 or the dim ramp at 0-3, so none of them lands on white, cyan or orange. It restricts the range rather than rescaling it: the mapping is not monotonic in brightness, since popcount order and ordinary-palette order are different orders. Separately, the palette is uploaded once per frame and only after `flip()` has waited for the tick, so the bytes land in the vertical blank. Uploading during active display tore the picture: the scanlines the beam reached between two uploads were drawn with the other palette, which put an orange band across the opening. Doing it after the page swap also guarantees each frame is shown under its own palette.

The bottom HUD keeps the ordinary colours throughout. The decay clears one bit per frame in a fixed cyclic order, so from 15 it can only reach indices whose cleared bits are consecutive in that order: 14, 13, 11, 7, then 12, 9, 3, 6, then 8, 1, 2, 4, then 0. Indices 5 and 10 are unreachable, which leaves them free for the bottom rule and the active indicator; the indicator is drawn at 10 in the opening rather than 15, because 15 is the solid. Index 4 is reachable, but it sits at brightness level 1 and the ordinary colour there has almost the same luminance as the grey it replaces.

The second half fades by geometry instead. The history page is transformed onto the cleared back page with HMMM (translation) or LRMM (zoom and rotation), the current mesh is drawn over it with LMMV, and HMMM captures the result as the next history frame. A translation writes 256-|dx| by 192-|dy| pixels, so a strip at the trailing edge is never written and keeps the colour-0 clear. A magnification is different: at a step of 251 every destination pixel has a source inside page 2, and an offline reproduction of the transform matches what the emulator produces exactly, all 49,152 pixels. There the history leaves by growing past the screen edge rather than by erosion. Both halves clear the destination first, because LRMM is issued as a transparent copy: the low nibble of the command byte is the logical operation, and the value used leaves the destination alone wherever the source pixel is colour 0. Coverage is not what the clear is for; every destination pixel of the magnification does have a source, but the ones reading colour 0 are never written and would otherwise keep what the back page held two frames ago. An opaque copy would make the clear unnecessary, and was measured at 16.3 against 16.2 frames per second in the opening, inside the resolution of the measurement, so both halves keep the same transform. No CPU framebuffer processing, no runtime floating point and no runtime sin/cos are used. The HUD is drawn after the capture and never enters the loop; the capture test checks that directly, by looking for the header strip on the history page at the place it occupies on screen.

LRMM fills the destination one pixel at a time: it reads the source at the current reading position, writes that pixel, and then advances the position. vx/vy are how far it advances, counted in 256ths of a pixel, so 256 means one whole source pixel and the copy comes out the same size. At 251 it advances a little less than a pixel each time and reaches the end of the destination before it has read all of the source, so a narrower strip of the source is spread across the whole screen: a magnification. A larger value shrinks instead. The source start places the screen centre on the history centre using the same half-width/half-height form as `panel_draw`. Page 2 occupies Y 512-703 in the shared coordinate space.

## Choosing bit 5 of R20 at run time

R20 carries HS at bit 0 and EPAL at bit 4, and the demo needs both. Bit 5 is not the same thing on every V9968 build. On the pinned openMSX fork it enables the extended commands: written without it, LRMM does nothing at all, and Scene 6 loses its feedback zoom and rotation while the rest of the picture is untouched. On HRA's June FPGA map, the map a MSXimus carries, that same bit selects flat interlace, which is not wanted, and LRMM works without it. Reported from real hardware: the demo had to be patched from 0x31 to 0x11 by hand to run, while the benchmark, which writes 0x11 and uses no extended command, ran as it was.

One constant cannot serve both, so `r20_select()` asks the hardware instead. It writes 0x11, fills one 8x2 rectangle on page 0, clears another, runs a 1:1 LRMM between them and reads the destination back. The read-back waits for CE in S#2 to rise and then clear, not just to be clear. The fork finishes the transfer immediately, so polling straight away happens to work there, but on real hardware LRMM takes time: a status read that beat CE going high would return at once, the destination would be read before the transfer arrived, and the probe would conclude nothing moved and set bit 5 on a machine where that bit means flat interlace. Missing the rising edge is harmless, because it can only mean the transfer already finished. If the transfer happened, extended commands are already live and the bit stays clear; if it did not, the bit is what turns them on and 0x31 goes in. Page 0 is cleared immediately afterwards, so the two rectangles leave nothing behind, and the chosen byte is reported at 0xcf09.

Measured on the fork: the read-back is 0x00 under 0x11 and 0xff under 0x31, so the probe discriminates in both directions rather than always landing on one answer. It selects 0x31 there, and the picture is pixel-identical to the build that wrote 0x31 unconditionally, in the opening and in both LRMM phases. The hardware branch has not been run on hardware here.

## Mapper choice, and growing past 1 MiB

`bank_select()` writes the low eight bits of the bank number as data and the high bits on A8–A11. That is the ASCII16-X encoding. With 64 banks the high bits are always zero, so every write lands on 7000H with the bank number as data — which is plain ASCII16. One implementation therefore satisfies both mappers, and the ROM runs unchanged on ASCII16-X hardware.

ASCII16 is declared because it is the far more widely implemented of the two, and nothing in this demo needs the extension. Note that the practical audience is currently emulator users: V9968 itself exists in hardware only as HRA!'s FPGA cartridge, so the wider mapper support matters as future headroom rather than as something users can exercise today.

The eight-bit register caps ASCII16 at 256 banks, or 4 MiB. To go beyond that:

1. Raise `ROM_BANKS` in `generate-megarom.py`. The generator refuses any value above 256 while `MAPPER` is `ASCII16`, and the assertion message names the replacement.
2. Set `MAPPER` to `ASCII16-X` in the same file.
3. Change `-romtype` in `launch.ps1`, `test.ps1` and `test-water.ps1`.
4. Update the 1,048,576-byte size checks in `launch.ps1` and `tests/validate-public.ps1`, and the `demo` entry in `config/versions.json`.

No change to `mapper.c`, `mapper.h` or any drawing code is required. Note that ASCII16-X also decodes register mirrors inside the 8000H–BFFFH data window; this demo only reads that window, so the mirrors are harmless here, but any future code that writes into it must avoid them.

`platform.c` is independently implemented. At cartridge startup the BIOS is mapped in page 0; turbo R alone calls CHGCPU (0180h) with A=81h for R800 ROM mode. Keyboard reads use PPI AAh/A9h and restore the selector after each read. No copied library implementation is included.

## Tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File test.ps1 -Runtime "C:\path\to\runtime\fsa1gt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File test-water.ps1 -Runtime "C:\path\to\runtime\fsa1gt"
```

Use `cbios` instead for C-BIOS. `test.ps1` checks six scenes, keys 1/3/0/W/Esc, VDP faults, banking, backgrounds, the header of every scene pixel by pixel, that the Scene 3 header rows move with the water, and that the R20 probe selected the byte this fork needs. Scene 6 is selected with its key rather than by waiting for the automatic cycle: interrupts are disabled while drawing, so the tick clock drifts behind real time by an amount that differs between Z80 and R800. `test-water.ps1` compares identity and normal water distortion against an independent reference. `test-output/` may contain owned BIOS copies and is excluded from publication. Normal launch data uses `runtime/<mode>/user-tech-demo/<first 12 SHA-256 characters>/`.

See [0.7.0 test results (JSON)](verification.json). Physical hardware, other emulators, sizes beyond 4 MiB, playback beyond 18 minutes and audio quality are untested. The 16-bit clock wraps at about 18 minutes. CPU/font identification does not guarantee every feature.

W is keyboard matrix row 5, bit 4. Tests verify that Y has no effect, holding W does not toggle repeatedly, and releasing and pressing W again toggles back. At completed-frame boundaries, the rendered VRAM body must match the captured source when OFF and differ when ON. Input is injected into the emulator keyboard matrix; this is not a physical-keyboard test.

## References

- [Pinned VDP command implementation](https://github.com/buppu3/openMSX/blob/d884c4b/src/video/VDPCmdEngine.cc)
- [openMSX ASCII16 implementation](https://github.com/openMSX/openMSX/blob/RELEASE_21_0/src/memory/RomAscii16kB.cc)
- [ASCII16-X](https://www.grauw.nl/projects/ascii-x/ascii16-x/), the superset this ROM also runs on
- [PPI / keyboard register overview](https://map.grauw.nl/resources/msx_io_ports.php)
- [Keyboard matrices](https://map.grauw.nl/articles/keymatrix.php)

## Teaser GIF

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File test.ps1 -Runtime "C:\path\to\runtime\fsa1gt" -CaptureScript capture-water.tcl
python make-preview.py "test-output\run-folder\user\screenshots" water-preview.gif
```

Capture 16 actual Scene 3 frames from the current ROM, upscale 2× (640×480) with nearest-neighbor sampling, and loop at 130 ms per frame. The silent GIF is a roughly 2.08-second excerpt, not a measurement of demo FPS. Use `--scale 1` for native resolution.

- [MSX Technical Data Book, section 1.3.5: keyboard matrix](https://map.grauw.nl/resources/system/msxtech.pdf) (2026-09-10)
