[日本語](bios-dump.ja.md) | English

# Dump and join FS-A1GT ROMs

[Home](../README.md)

| Final filename | Size | Purpose |
|---|---:|---|
| `fs-a1gt_firmware.rom` | 4,194,304 bytes / 4 MiB | The openMSX combined firmware image: BIOS/BASIC, sub-ROM, disk components and built-in software |
| `fs-a1gt_kanjifont.rom` | 262,144 bytes / 256 KiB | JIS first- and second-level Kanji font |

A physical dump of the ROM chips is not necessarily the same layout as this 4 MiB emulator image. The following method runs a dump program on your own working machine without disassembly. Keep the resulting ROMs private.

## Prepare media and programs

Use a working FS-A1GT and its internal floppy drive, a program disk and roughly eight blank 720 KiB 2DD disks for output. The 32 firmware parts take seven disks when five parts fit on each disk. You also need a PC transfer method that reads these disks; not every USB floppy drive supports 720 KiB media. Do not format disks containing data you need. Existing SD storage may work, but this guide assumes the program's A: drive and floppy-swap workflow; other drive mappings are untested.

Use **Panasonic dump tools → FS-A1GT** on the [blueMSX developer resource page](https://www.vik.cc/bluemsx/resource.html), not a machine/ROM bundle:

- [FSA1GT.zip dump tools](https://www.vik.cc/bluemsx/rel_download/dump/FSA1GT.zip): FSA1GT.BAS and FSA1GT.DSK.
- Optional [KANJIROM.zip](https://www.vik.cc/bluemsx/rel_download/dump/KANJIROM.zip): KANJIROM.BAS and KANJIROM.DSK.

These third-party tools are not bundled here. Copy the BAS files onto the program disk using normal file transfer. A DSK file is a whole-disk image: merely copying it as a file to a floppy does not unpack its contents. The BAS-file method does not require writing DSK images.

## Run on the machine

1. Turn off built-in firmware startup and insert the program disk.
2. **Hold the keyboard's 1 key while booting**, as specified by the dump-tool page for turboR. Use the Disk BASIC 1 route, not the normal Disk BASIC 2 startup.
3. At BASIC's Ok prompt run:

```basic
RUN "FSA1GT.BAS"
```

If your disk boots into DOS, enter `BASIC` first. Follow the program's menu and disk-swap prompts.

## Main ROMs and Kanji

Choose **1: Main System ROM BIOS** and insert a blank output disk when prompted. The source saves BIOS, extended BIOS, Kanji driver, Kanji font, music BASIC, opening and disk components. For this setup, keep **A1GTKFN.ROM**, the 256 KiB font file. A1GTBIOS.ROM alone cannot replace the 4 MiB combined image. After writing finishes, transfer the files to Windows.

To dump just the font separately, run `RUN "KANJIROM.BAS"` and choose **2: JIS 1st/2nd Class Kanji**. It creates **KANJI.ROM**, 256 KiB. Menu item 1 only saves 128 KiB and is insufficient. The same hold-1-at-boot instruction applies.

## Internal firmware

In FSA1GT.BAS choose **2: Internal Firmware ROMS**. Keep swapping blank disks when prompted. Collect all **32 files**, each **131,072 bytes**, into one Windows folder:

```text
A1GTFIRM.000 ... A1GTFIRM.009
A1GTFIRM.00A ... A1GTFIRM.00F
A1GTFIRM.010 ... A1GTFIRM.019
A1GTFIRM.01A ... A1GTFIRM.01F
```

The suffix is hexadecimal. Keep a record of the parts on each disk. Put A1GTKFN.ROM or KANJI.ROM in the same folder.

The source explicitly fills some firmware regions with FF. This creates a logical image for this tool/emulator workflow, not a bit-for-bit physical chip archive. Compatibility is determined by the final hashes below.

## Join and validate on Windows

Drag the collected folder onto **tools\bios\join-fsa1gt-dump.bat** under tools/bios. Double-clicking opens a folder picker. The default output is private/fsa1gt-bios. Alternatively, from Command Prompt:

```bat
tools\bios\join-fsa1gt-dump.bat "D:\FS-A1GT dump" -OutputDir "D:\FS-A1GT ready"
```

The output folder must not already exist. The helper concatenates parts in numeric order and verifies both images before writing them under the final filenames. It does not change input files, patch data or fill missing parts.

| Image | Accepted SHA-1 |
|---|---|
| Firmware | `e779c338eb91a7dea3ff75f3fde76b8af22c4a3a` or `5fa3aa79aeba2c0441f349e78e9a16d9d64422ea` |
| Kanji | `5aff2d9b6efc723bc395b0f96f0adfa83cc54a49` |

These values come from the [official openMSX 21.0 FS-A1GT XML](https://github.com/openMSX/openMSX/blob/RELEASE_21_0/share/machines/Panasonic_FS-A1GT.xml). A mismatch stops output. Check missing/mixed parts, transfer errors, tool versions and machine revisions. If possible, repeat the dump onto another set of blank disks and compare both results. Do not add an unexplained hash just to make the test pass.

Drag the successfully created output folder onto setup-fsa1gt-v9968.bat to continue.

## Evidence and limits

We checked the downloaded BAS sources for menu choices, filenames, block count and font levels. We tested joining 32 parts made from a locally owned compatible ROM and recovered the original hash. **We have not operated the physical FS-A1GT to perform this dump.** The joining test does not establish physical-machine compatibility. See the [openMSX dumping guide](https://openmsx.org/manual/setup.html#dumprom) as well. Renaming a generic 32 KiB BIOS dump cannot turn it into the required combined image.

Tool archive SHA-256, measured locally on 2026-09-09:

- FSA1GT.zip: `E9CE0ED60E7BD0910E85A31E7EE6C266DF277F95AD974E537D6DCEE0C4BEF2E8`
- KANJIROM.zip: `20DF14B76D575D29DDE6549141B90D907171E4A4DBEFB0D4F6586054568D9D9C`
