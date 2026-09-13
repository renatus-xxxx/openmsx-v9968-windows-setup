[日本語](v9968-divergence.ja.md) | English

[Home](../README.md)

# Where V9968 implementations disagree

There is no single agreed V9968. The chip was never mass produced, so every
implementation is someone's reading of the specification, and at least one
register bit already means different things in different ones. That was not
found by reading documents. It was found when a demo written against an
emulator would not run on FPGA hardware until one byte was changed.

This page is the list of the places where implementations are known or
suspected to part company, and what each one has actually been observed to do.
It is deliberately a record of observations, not a ruling on which behaviour is
correct.

## How to add a column

Run `probe/PROBE.rom` on your machine. It prints one line per test and stops.
Report the lines exactly as printed, together with what you ran it on.

Use this cartridge from a fresh startup. It overwrites scratch VRAM and VDP
registers, then initializes a new text screen with BIOS INITXT. It does not
preserve a running application. Requested addresses are at or above 0x8000,
but unknown address decoding may alias them below that boundary. No disk or
flash programming is performed. Physical FPGA execution remains unverified;
reset the machine if the report does not finish. This is currently an internal
VDP test using ports 98h/99h, not an external cartridge test on ports 88h/89h.

```
V9968 / C ROM TEST
VDP ID=3
V9968 IDENTIFIED
R20B5  off=0 on=1
R20SEL value=31
LRMMOP timp=ff imp=00
LRMMST d0=1 d1=2
CE     rise=0 fall=15
CESEEN value=1
VRAM   a1 a2 a3 a4
REPORT THESE LINES
```

## The table

The original measurements below were taken on the pinned fork listed in
[versions](../config/versions.json), running C-BIOS on 2026-09-13. The original
ROM hash was `ca026fedd55dca1573846d48f9b60dd49aa261d63f5d743c0556be4be0203f79`.
The example also shows the added R20SEL/CESEEN diagnostics; CE poll counts are
build dependent and are not acceptance thresholds. See [current probe checks](../probe/verification.json)
for the rebuilt ROM and actual output. The FPGA column is what the demo's behaviour on
hardware implies, not a probe run: nobody has reported probe output from
hardware yet.

| Line | Pinned fork | FPGA | Agreed? |
| --- | --- | --- | --- |
| `VDP ID=` | 3 | 3 | yes |
| `R20B5 off=` | 0 | 1 expected | **no** |
| `R20B5 on=` | 1 | 1 expected, not measured | unknown |
| `LRMMOP timp=` | ff | not reported | unknown |
| `LRMMOP imp=` | 00 | not reported | unknown |
| `LRMMST d0=` | 1 | not reported | unknown |
| `CE rise=` | 0 | not reported | **expected to differ** |
| `VRAM` | a1 a2 a3 a4 | not reported | unknown |

## What each line tests

### `VDP ID=` — the identification sequence

Reads the VDP identification the way HRA!'s `init_vdp()` does. A V9968 answers
3. Anything else means the rest of the tests were skipped.

### `R20B5` — what bit 5 of R20 does

**This is the confirmed divergence, and the reason this page exists.**

The test writes R20 without bit 5, runs one 1:1 LRMM between two small
rectangles, and reads the destination back; then it does the same with the bit
set. `off=1` means the extended commands work without the bit.

On the pinned fork bit 5 enables the extended commands: clear it and LRMM does
nothing at all. On the FPGA map documented by HRA! the same bit selects flat
interlace, and LRMM works without it. One constant cannot serve both, which is
why the demo picks the value at boot by running this same experiment.

Writing 0x31 for the emulator may select flat interlace on the FPGA; writing
0x11 for the FPGA disables LRMM on the pinned emulator. The probe tests both,
then prefers 0x11 if it worked. Otherwise it uses 0x31 if that worked. R20SEL
reports this choice. If neither worked, LRMMOP/LRMMST are skipped rather than
interpreting an unchanged destination as a logical-operation result.

### `LRMMOP` — the logical operation on LRMM

The low four bits of the command byte are the logical operation. Operation 8 is
the transparent variant, which must leave the destination alone wherever the
source pixel is colour 0; operation 0 must overwrite it.

The test fills the source with colour 0 and the destination with colour 15,
then runs LRMM twice. `timp=ff` means the transparent operation left the
destination untouched, `imp=00` means the opaque one overwrote it. Any other
pair means the operation field is not being applied to LRMM the same way.

This matters more than it looks. A transparent transform does not write every
destination pixel, so code that relies on it to cover the screen has to clear
the destination first. Getting this wrong produces stale content rather than an
error.

### `LRMMST` — where the source reading position starts

LRMM fills the destination one pixel at a time while advancing a reading
position in the source. Whether it advances before writing a pixel or after it
shifts the whole result by one source pixel.

The test copies a row whose pixels are 1, 2, 3 and so on, one to one, opaque.
The destination is initialized to 15, and the first two copied pixels are read
from one byte. `d0=1 d1=2` supports reading before advancing; `d0=2 d1=3`
supports advancing first. Other pairs are inconclusive, not automatically a
different stepping rule.

### `CE` — how long the command engine takes

`rise` counts how many status reads happened before the engine reported itself
busy; `fall` counts the reads it stayed busy for. The command is a fill over a
whole page, so a real chip has work to do.

These are software polling counts, not elapsed time or a VDP speed ratio.
Record CPU mode, clock, ROM hash, emulator/FPGA revision and R20SEL with them.
The fill is HMMV, 256x192, SCREEN 5, display blanked, interrupts disabled.
CESEEN=0 means no busy pulse was observed within 20,000 polls; the command
could have finished unseen or not started. A busy period exceeding 60,000 polls
is an error, not a measured duration. Other commands have a 1,024-poll start
grace period and 20,000 busy polls. These bounds prevent unbounded software
loops but are not justified hardware timing limits. PROBE ERROR code=1 means
a busy timeout; code=2 means the source/destination preparation failed. Partial
results are discarded and the text screen is initialized after an abort.

For cross-machine timing, a future test should run repeated commands over a
long interval measured with a documented common timer or VBlank count. Very
short CE pulses require a cycle-accounted loop or external measurement. This
probe makes no physical-hardware timing guarantee.

### `VRAM` — how much memory is really addressable

Writes markers at 0x8000, 0x10000, 0x18000 and 0x1c000 (R14=2,4,6,7 and
offset=0), then restores the saved bytes. R14 selects a 16 KiB block, not a
SCREEN 5 page. The last gap is 16 KiB. Distinct markers establish only that
these four addresses do not alias in this mode; they do not prove complete
128 KiB coverage or 256 KiB capacity. Repeated markers can indicate aliasing,
but missing writes or read timing failures must also be excluded.

## Not yet tested

These are suspected to vary but no experiment has been written for them. They
would be the next things to add to the cartridge.

- **LRMM clipping.** When a rotated or magnified read falls outside the source
  clip window, is the destination pixel left alone or written as colour 0? The
  demo's Scene 6 relies on the history not leaking in from the neighbouring
  page, and clears the destination first, so it has never had to find out.
- **The extended palette.** Whether entries can be read back at all, and
  whether the write port auto-increments the same way everywhere.
- **The remaining bits of R20.** Only bit 0, bit 4 and bit 5 are exercised
  here, because only those are used by the demo.
- **Command timing per command.** `CE` measures one fill. A table across the
  command set would say much more, and would need a timer rather than a poll
  count to be comparable between machines.

## Why a list rather than a patch

Upstream openMSX judges an implementation against real hardware. For a chip
with no mass-produced part, the first thing missing is not code but an agreed
answer to what the hardware does. A table that several implementations have
filled in is the thing that makes that conversation possible, and it is
something that can be built without owning every implementation.
