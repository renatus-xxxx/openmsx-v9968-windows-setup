[日本語](bios-dump.ja.md) | English

# Dump and join FS-A1GT ROMs

[Home](../README.md)

This setup needs the two files below. They are identified by size and hash, not by filename alone.

| Final filename | Size | Purpose |
|---|---:|---|
| `fs-a1gt_firmware.rom` | 4,194,304 bytes / 4 MiB | The openMSX combined firmware image: BIOS/BASIC, sub-ROM, disk components and built-in software |
| `fs-a1gt_kanjifont.rom` | 262,144 bytes / 256 KiB | JIS first- and second-level Kanji font |

A physical dump of the ROM chips is not necessarily the same layout as this 4 MiB emulator image. The following method runs a dump program on your own working machine without disassembly. Keep the resulting ROMs private.

## 1. What to prepare

- A working FS-A1GT with a working internal floppy drive.
- Media and a drive that can move files between the MSX and Windows. The steps below use 720 KiB 2DD floppy disks; not every USB floppy drive reads 720 KiB media.
- One program disk and roughly eight blank disks for output. The 32 firmware parts alone take seven disks when five parts fit on each disk. Do not format disks containing data you need.
- An empty folder on Windows to collect the extracted files.

Existing SD storage may also work, but the dump program saves to A: and prompts for disk swaps. Other drive mappings are untested, so this guide uses the internal floppy drive.

## 2. Get the dump program

Use **Panasonic dump tools → FS-A1GT** on the [blueMSX developer resource page](https://www.vik.cc/bluemsx/resource.html). Choose the dump-tool links, not a machine/ROM bundle.

- [FSA1GT.zip dump tools](https://www.vik.cc/bluemsx/rel_download/dump/FSA1GT.zip)
- Only if you need it: [KANJIROM.zip Kanji dump tools](https://www.vik.cc/bluemsx/rel_download/dump/KANJIROM.zip)

Contents as downloaded on 2026-09-09:

| ZIP | Contents |
|---|---|
| FSA1GT.zip | `FSA1GT.BAS`, `FSA1GT.DSK` |
| KANJIROM.zip | `KANJIROM.BAS`, `KANJIROM.DSK` |

These third-party tools are not bundled here; get them from the source above. Copy the BAS files onto the program disk using normal file transfer. A DSK file is a whole-disk image: copying it as a file to a floppy does not unpack its contents. The BAS-file method does not require writing DSK images.

## 3. Start the machine

1. Turn off built-in firmware startup and insert the program disk.
2. **Hold the keyboard's 1 key while booting**, as specified by the dump-tool page for turboR. Use the Disk BASIC 1 route, not the normal Disk BASIC 2 startup.
3. At BASIC's `Ok` prompt run:

```basic
RUN "FSA1GT.BAS"
```

If your disk boots into DOS, enter `BASIC` first. Then follow the program's menu and disk-swap prompts.

## 4. Save the main ROMs and Kanji font

Choose **1: Main System ROM BIOS** and insert a blank output disk when prompted.

This choice saves BIOS, extended BIOS, Kanji driver, Kanji font, music BASIC, opening and disk components. Of these, the file needed here is **`A1GTKFN.ROM`**, the 256 KiB font. `A1GTBIOS.ROM` alone cannot replace the 4 MiB combined image.

When writing finishes, transfer the files to Windows. Do not eject a disk while it is being written.

To dump just the font separately, run `RUN "KANJIROM.BAS"` and choose **2: JIS 1st/2nd Class Kanji**. It creates **`KANJI.ROM`**, 256 KiB. Menu item 1 saves only the first level, 128 KiB, which is not enough here. The same hold-1-at-boot instruction applies.

## 5. Save the internal firmware

Back in FSA1GT.BAS, choose **2: Internal Firmware ROMS**. Keep swapping blank disks when prompted.

The result is **32 files, `A1GTFIRM.000` to `A1GTFIRM.01F`**, each **131,072 bytes / 128 KiB**. The suffix is hexadecimal.

```text
A1GTFIRM.000 ... A1GTFIRM.009
A1GTFIRM.00A ... A1GTFIRM.00F
A1GTFIRM.010 ... A1GTFIRM.019
A1GTFIRM.01A ... A1GTFIRM.01F
```

Keep a record of which parts are on each disk, then collect all 32 files into one Windows folder. Put `A1GTKFN.ROM` or `KANJI.ROM` in the same folder.

**The tool's source explicitly fills some firmware regions with FF.** What you create here is therefore a logical image for this tool and emulator workflow, not a bit-for-bit archive of the physical chips. Acceptance is decided by the hash check below.

## 6. Join and validate on Windows

Drag the collected folder onto **`tools\bios\join-fsa1gt-dump.bat`**. Double-clicking opens a folder picker. The default output is private/fsa1gt-bios. From Command Prompt you can also choose the output path:

```bat
tools\bios\join-fsa1gt-dump.bat "D:\FS-A1GT dump" -OutputDir "D:\FS-A1GT ready"
```

The output folder must not already exist. The helper concatenates the parts in numeric order and verifies both images before writing them under the final filenames. It does not change input files, patch data or fill in missing parts.

| Image | Accepted SHA-1 |
|---|---|
| `fs-a1gt_firmware.rom` | `e779c338eb91a7dea3ff75f3fde76b8af22c4a3a` or `5fa3aa79aeba2c0441f349e78e9a16d9d64422ea` |
| `fs-a1gt_kanjifont.rom` | `5aff2d9b6efc723bc395b0f96f0adfa83cc54a49` |

These values come from the [official openMSX 21.0 FS-A1GT XML](https://github.com/openMSX/openMSX/blob/RELEASE_21_0/share/machines/Panasonic_FS-A1GT.xml). A mismatch stops output before anything is written.

If the hashes do not match, check for missing parts, a mixed-up disk, transfer errors, the dump tool version and your machine's ROM revision. If possible, repeat the dump onto another set of blank disks and compare the two results. Adding an unexplained hash to force the check to pass is not part of this procedure.

Once the folder is created successfully, drag it onto `setup-fsa1gt-v9968.bat` to continue.

## What we verified

- We checked the downloaded BAS sources for the menu choices, filenames, block count and font levels, along with the boot instruction given by the distributor.
- We tested that the join helper recovers the original hash from a locally owned compatible ROM split into 32 parts.
- **We have not operated a physical FS-A1GT to perform this dump.** The joining test does not establish that the dump succeeds on real hardware, nor that these tools behave as described on a real machine.
- The [openMSX dumping guide](https://openmsx.org/manual/setup.html#dumprom) is also useful background. Renaming a generic 32 KiB BIOS dump cannot turn it into the required combined image.

## Tool archive SHA-256 (measured locally)

Measured on 2026-09-09:

- FSA1GT.zip: `E9CE0ED60E7BD0910E85A31E7EE6C266DF277F95AD974E537D6DCEE0C4BEF2E8`
- KANJIROM.zip: `20DF14B76D575D29DDE6549141B90D907171E4A4DBEFB0D4F6586054568D9D9C`
