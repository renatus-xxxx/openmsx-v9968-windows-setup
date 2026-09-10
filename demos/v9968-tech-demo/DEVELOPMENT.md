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

Editable sources are `assets/chamber-source.png` and `assets/seabed-source.png`. `python convert-assets.py` generates the 16-color images. [MSX 8x8 font](third-party/fonts/README.md) is converted and composed into background titles and scene labels. `assets/PROMPT.txt` records image generation settings.

SCREEN 5 uses 256×192 with 16 colors, the extended palette, HS and LRMM. Pages 0/1 alternate drawing/display; page 3 stores backgrounds and 56×8 scene labels; page 2 holds textures or the water source. Scene 3 restores the top 16 rows to keep text stationary.

Rotation/projection, solid spans, floor/panel/water parameters are precomputed. Fixed code uses 4000–7FFF; 8000–BFFF is the data window for 64 ASCII16 banks, selected through the register at 7000H. Because every bank number stays below 256, the write is plain ASCII16 and behaves identically on ASCII16-X hardware. The interrupt never switches banks. CF00 onward holds telemetry; D000–D100 and D1D1–D1D3 are reserved for IM2.

Stride-addressed assets emit a `FRAMES_<NAME>` constant into `bank-layout.h`. The runtime masks frame indices with `FRAMES_<NAME>-1`, so a change to the generated frame count cannot silently read into the next asset. The generator asserts that each count is a power of two of at most 256.

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

Use `cbios` instead for C-BIOS. `test.ps1` checks five scenes, keys 1/3/0/W/Esc, VDP faults, banking, backgrounds and labels. `test-water.ps1` compares identity and normal water distortion against an independent reference. `test-output/` may contain owned BIOS copies and is excluded from publication. Normal launch data uses `runtime/<mode>/user-tech-demo/<first 12 SHA-256 characters>/`.

See [0.6.0 test results (JSON)](verification.json). Physical hardware, other emulators, sizes beyond 4 MiB, playback beyond 18 minutes and audio quality are untested. The 16-bit clock wraps at about 18 minutes. CPU/font identification does not guarantee every feature.

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
