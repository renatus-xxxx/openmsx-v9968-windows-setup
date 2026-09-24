[日本語](README.ja.md) | English

**2026-09-24 update:** The pinned-fork specifications and measurements below describe d884c4b. With current 14215c7, the same Revision 2 ROM reports off=1/on=1 and R20SEL=11. See the [new emulator validation](../docs/emulator-update-20260924.md). Original tables and source references are retained as historical evidence.

# V9968 PROBE Revision 2

Revision 2 is included in release 0.7.1. FPGA hardware retesting remains pending.

ROM SHA-256: `3527684d4cdaf58659ff7a6363d4cdce263e10959686dc93f091d918ea8287d2`

[Detailed test results (JSON)](verification.json)

[Build instructions](../docs/development.md)

## V9968 conformance probe

- Revision 2 | 2026-09-14
- R21 compatibility fix and separate LRMM diagnostics
- C / z88dk / pinned openMSX fork
- The revised ROM has not yet been retested on FPGA hardware

## Reported FPGA observations

- Released 0.7.0 probe: off=0 / on=0; LRMM tests skipped
- The tester reported that the demo selected 0x11 and ran Scene 6 on the same hardware
- R20SEL=31 was a fallback, not a successful selection
- HMMV busy observations and VRAM markers completed; neither proves LRMM worked

## R21 changed the experiment mode

- Old probe: identify with R21=0x3a → restore 0x3b → test LRMM
- Working demo: retain R21=0x3a while executing LRMM
- In the public FPGA source, bit 0 is the compatibility flag; extended-command enable is its inverse
- Revision 2 retains the extended setting and checks EXTID=3 immediately before testing

## R20 and R21 have different roles

| Setting | Pinned fork | Public FPGA definition |
| --- | --- | --- |
| R21 bit 0 | Affects identification | 1=V9958 compatible / 0=extended |
| R20 bit 5 | Extended-command gate | Flat interlace |
| R20 0x11 | HS + EPAL | HS + EPAL |
| R20 0x31 | Above + bit 5 | Above + FIL |

## Revision 2 execution sequence

- Identify → SCREEN 5, display off, interrupts disabled
- Check EXTID → test both R20 settings in low VRAM
- Select a successful setting → high VRAM, transparency and source-step tests
- Observe HMMV CE → four VRAM locations → normalize, INITXT, print

## Match the demo in low VRAM

- Source (0,0) → destination (16,0), 8×2 pixels, identity transparent LRMM 0x38
- Prepare source color 15 and destination color 0 using LMMV
- Clip X=0..255, Y=0..191; read back through R14=0
- Check all 16 prepared and transferred pixels, not just the first byte

## R20 selection rules

| off | on | Selection / interpretation |
| --- | --- | --- |
| 1 | 0 or 1 | Choose 0x11; prefer bit 5 clear |
| 0 | 1 | Choose 0x31 |
| 0 | 0 | NONE; skip dependent LRMM tests |

## Separate transfer results from CE observations

- LRRAW: hexadecimal first destination byte for each setting
- LRCE: whether the start-wait loop observed CE=1 for each LRMM
- A transfer can pass the full readback check even if LRCE=0
- Pinned fork: LRRAW off=00 on=ff / LRCE off=0 on=0

## CE waiting and bounds

- S#2 bit 0: 1=command executing, 0=not executing
- Before launch: idle() waits for the previous command
- After launch: up to 1024 start polls, then up to 20000 completion polls
- Completion timeout: ABRT, fault=1, stop later tests; fixed counts are not hardware guarantees

## The CE line diagnoses HMMV

- Fill a 256×192 region using HMMV 0xc0
- rise counts zero samples before CE=1; bound 20000
- fall counts one samples before CE=0; bound 60000
- Counts depend on CPU, compiler, display and R20; 14 versus 15 does not establish a speed difference

## Test high-VRAM LRMM separately

- Repeat the 8×2 transfer at Y=256 using the selected R20
- Clip Y=256..1023; read back with R14=2
- LRHIGH ok=1 enables the transparency and source-step tests
- Low success with high failure points to address/clip conditions, not general LRMM absence

## Transparent and opaque transfers

- At Y=258, prepare source color 0 and destination color 15
- 0x38: transparent operation should retain destination 0xff
- 0x30: opaque operation should overwrite with 0x00
- timp=ff / imp=00 characterizes this zero-color case, not every logical operation

## Source-coordinate advancement

- Prepare input pixels 1,2,3,4,5,6,7,8 at Y=260
- Copy four pixels opaquely at identity scale; print the first two
- d0=1 / d1=2 is consistent with sampling before a one-pixel advance
- d0=2 / d1=3 suggests pre-advance; other values require further diagnosis

## VRAM locations and address calculation

| R14 | Low 14 bits | Requested address |
| --- | --- | --- |
| 2 | 0 | 0x08000 |
| 4 | 0 | 0x10000 |
| 6 | 0 | 0x18000 |
| 7 | 0 | 0x1c000 |

## Text restoration and execution conditions

- Fresh cartridge startup only; experiments overwrite VRAM and registers
- Finish with ABRT, zero R20/R14/R15/R16/R17 and restore R21=0x3b
- BIOS INITXT (0x006c) → enable interrupts → print report
- No disk or flash writes; previous screen/application state is not restored

## Revision 2 sample output

- PROBE REV=2 / EXTID=3 R21=3a
- R20B5 off=0 on=1 / R20SEL value=31
- LRRAW off=00 on=ff / LRCE off=0 on=0
- LRHIGH ok=1 raw=ff / LRMMOP timp=ff imp=00
- LRMMST d0=1 d1=2 / CE rise=0 fall=15 / CESEEN value=1
- VRAM a1 a2 a3 a4 / REPORT THESE LINES

## Errors and skips

| Output | Meaning |
| --- | --- |
| PROBE ERROR code=1 | Command completion wait exceeded its bound |
| PROBE ERROR code=2 | Prepared VRAM data failed readback |
| PROBE ERROR code=3 | EXTID was not 3 immediately before testing |
| R20SEL NONE | Neither R20 setting passed transfer verification |
| LRMM TESTS SKIPPED | No selection or high-VRAM transfer failed |

## Emulator verification

| Configuration | CPU | Result |
| --- | --- | --- |
| C-BIOS + V9968 fork | Z80 | Revision 2 experiments completed |
| FS-A1GT + V9968 fork | Z80 | Same results and text restoration |
| C-BIOS + openMSX 21.0 | Z80 | ID=2 / experiments skipped |
| FS-A1GT + openMSX 21.0 | Z80 | ID=2 / experiments skipped |

## Negative tests use separate ROMs

- Replace LRMM launch with ABRT → verify NONE and skip handling
- Set R21=0x3b before EXTID → verify error 3
- Reduce HMMV completion budget to 1 → verify error 1
- Artificially exercise the 0x11 branch → verify selection and high-failure handling

## Requesting a hardware retest

- Use the Revision 2 ROM and confirm PROBE REV=2 on screen
- Start from power-on and capture the complete screen without patching settings
- Report device/FPGA firmware, MSX model, CPU mode and ROM SHA-256
- Report NONE or errors as-is; do not patch R20 to match an expected answer

## C build and reproducibility

- zcc +msx -subtype=rom -compiler=sccz80 -O2 -create-app probe.c -o PROBE
- Output: 16 KiB ROM; only rebuilding requires z88dk
- The repository provides scripts/build-probe.ps1 -Z88dk <toolchain>
- Keep source, ROM, verification.json and configured hashes on the same revision

## Limitations and primary sources

- FPGA retest, R800, external 88h/89h ports and hardware wait bounds remain unverified
- No coverage of 256 KiB capacity, negative steps, fractional rounding, clip edges or palette readback
- FPGA Register Map: R20 Mode5 / R21 Mode6 (printed p.10)
- Pinned FPGA source: vdp_cpu_interface.v; pinned fork: VDP.cc and VDPCmdEngine.cc

## Primary references

- [Source 1](https://github.com/hra1129/V9968_Cartridge/blob/9c2eb1d1445bbc23a3bdac3916cfa147519452f8/fpga/V9968_Cartridge_TangNano20K/src/v9968/vdp_cpu_interface.v)
- [Source 2](https://github.com/hra1129/V9968_Cartridge/blob/9c2eb1d1445bbc23a3bdac3916cfa147519452f8/fpga/V9968_Cartridge_TangNano20K/src/v9968/manual/v9968_programmers_manual_register_map.pdf)
- [Source 3](https://github.com/buppu3/openMSX/blob/d884c4b/src/video/VDP.cc)
- [Source 4](https://github.com/buppu3/openMSX/blob/d884c4b/src/video/VDPCmdEngine.cc)
