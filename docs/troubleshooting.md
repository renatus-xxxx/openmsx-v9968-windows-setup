[日本語](troubleshooting.ja.md) | English

# Troubleshooting and removal

[Home](../README.md)

Find your situation below. Setup and launch write a log, and the message on screen names the log path; open it first when a cause is not obvious.

## Setup does not start

| Condition | Action |
|---|---|
| Missing curl.exe | Update Windows and check System32/curl.exe; old Windows 10 releases may lack it |
| Windows policy blocks execution | Follow your organization's policy. These tools do not bypass AppLocker/WDAC |
| Destination is inside OneDrive | Setup stops rather than installing into a synced folder. Extract into a local folder outside the synced tree, such as C:\MSX. On Windows 11 with a Microsoft account, Desktop and Documents are usually synced |
| Destination contains a link or junction | Use an ordinary local folder. The path must not redirect anywhere |

## Download and verification

| Condition | Action |
|---|---|
| curl/network/HTTP error | Check HTTPS access and proxy settings, then retry. Do not disable certificate checks |
| Archive size or SHA-256 mismatch | Move the suspect cache file aside; check the pinned upstream release before downloading again |

## FS-A1GT BIOS

| Condition | Action |
|---|---|
| Missing/unknown BIOS | Check the two required images, sizes and hashes. Renaming a wrong ROM does not fix its content |
| Different accepted firmware versions found together | Put only the chosen pair in a separate folder |
| Join output already exists | Choose a new OutputDir; no existing output is overwritten |

## Launch

| Condition | Action |
|---|---|
| Probe launcher says Not installed / 未セットアップ | Run the matching setup BAT first |
| Existing installation changed | Setup stops instead of overwriting it. Use a new folder for a fresh environment |
| Missing runtime DLL | Check Windows/VC runtime status. No runtime installer is run automatically; clean OS VMs are untested |
| Machine XML fails | Use UTF-8 without BOM for XML. PowerShell scripts use UTF-8 with BOM for Windows PowerShell 5.1 |
| Normal emulator fails in a Japanese path | Use the BAT under tools/verify. Its working directory and ASCII relative data paths must stay together |

## Identification and behavior

| Condition | Action |
|---|---|
| Verification fails or times out | Inspect runtime/MODE/logs, graphics drivers and the desktop session. No full game compatibility is implied |
| BASIC/BLOAD does not work in C-BIOS | Use a cartridge image or your own compatible FS-A1GT BIOS environment |

## Remove

1. Close openMSX and its BAT window. Process-local settings expire, and your original emulator still starts through its original shortcut.
2. Back up any saves you need.
3. With Explorer, delete only the folders this project generated: runtime, cache, private, build and dist.

Failed staging directories and lock/part files can also be deleted once all related processes have stopped. Do not delete your original BIOS directory or another emulator installation. No registry repair or administrator uninstaller is needed.

## Demo launch errors

- `Run setup-... first`: run the matching root setup BAT.
- `Emulator hash mismatch`: the emulator differs from the verified version. Extract the entire ZIP into another folder and set it up again.
- `Demo ROM is missing` / `Expected a 1 MiB ASCII16 ROM`: extract the whole ZIP. Developers can rebuild the demo and launch that build with `-UseBuild`.
- `Cached demo ROM hash mismatch` / `Local BIOS copy differs`: an existing demo copy differs from its source. Back up and rename the affected folder under `runtime/<mode>/user-tech-demo/`, then relaunch. Do not delete the original owned BIOS or the entire runtime.
- If the path is too long, extract the entire ZIP into a shorter writable location.
