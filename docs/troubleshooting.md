[日本語](troubleshooting.ja.md) | English

# Troubleshooting and removal

[Home](../README.md)

| Condition | Action |
|---|---|
| Root launcher says Not installed / 未セットアップ | Run the matching setup BAT first |
| Missing curl.exe | Update Windows and check System32/curl.exe; old Windows 10 releases may lack it |
| curl/network/HTTP error | Check HTTPS access and proxy settings, then retry. Do not disable certificate checks |
| Archive size or SHA-256 mismatch | Move the suspect cache file aside; check the pinned upstream release before downloading again |
| Missing/unknown BIOS | Check the two required images, sizes and hashes. Renaming a wrong ROM does not fix its content |
| Different accepted firmware versions found together | Put only the chosen pair in a separate folder |
| Existing installation changed | Setup stops instead of overwriting it. Use a new folder for a fresh environment |
| Machine XML fails | Use UTF-8 without BOM for XML. PowerShell scripts use UTF-8 with BOM for Windows PowerShell 5.1 |
| Normal emulator fails in a Japanese path | Use the BAT under tools/verify. Its working directory and ASCII relative data paths must stay together |
| Verification fails or times out | Inspect runtime/MODE/logs, graphics drivers and the desktop session. No full game compatibility is implied |
| Missing runtime DLL | Check Windows/VC runtime status. No runtime installer is run automatically; clean OS VMs are untested |
| BASIC/BLOAD does not work in C-BIOS | Use a cartridge image or your own compatible FS-A1GT BIOS environment |
| Windows policy blocks execution | Follow your organization's policy. These tools do not bypass AppLocker/WDAC |
| Join output already exists | Choose a new OutputDir; no existing output is overwritten |


## Remove

Close openMSX and its BAT window. Process-local settings expire; your original emulator can still start through its original shortcut. Back up needed saves, then remove only this project's generated runtime, cache, private, build and dist folders with Explorer. Failed staging directories and lock/part files can also be removed after all relevant processes stop. Do not delete your original BIOS directory or another emulator installation. No registry repair or administrator uninstaller is needed.

