[日本語](CHANGELOG.ja.md) | English

[Home](../README.md)

# Changelog

## 0.6.1

- Declare the tech demo ROM as standard ASCII16 instead of ASCII16-X. The bank switching code is unchanged, and the same ROM still runs on ASCII16-X hardware.
- Use the shipped demo ROM by default; developers select their own build with `-UseBuild`.
- Generate frame counts into the bank layout and mask frame indices with them, so a changed count cannot read into the following asset.
- Stop the asset generator when a ROM would exceed the 256-bank ASCII16 limit, naming ASCII16-X as the replacement.
- Match the mapper-failure screen to the V9968-missing screen, and remove an unreachable branch from the demo launcher.

## 0.6.0

- Add V9968 TECH DEMO with MSX 8x8 font, five scenes and PSG music.
- Add SCENE3 BENCHMARK comparing V9968 with a conventional VDP, with FULL/FAST/COMPAT modes and measured results.
- Print setup, launch and BIOS join messages in English and Japanese, and report the measured VDP ID when identification fails.
- Keep two setup BATs and two machine-specific demo BATs at the root.
- Move identification-screen launchers to `tools/verify/`.
- Use independent CPU-switching and keyboard implementations.
- Rework the guides: a route comparison in README, the restored structure of the English dump guide, and troubleshooting grouped by situation.

## 0.5.0 — Initial release

- Setup using C-BIOS or user-owned FS-A1GT BIOS.
- Pinned downloads and hash verification.
- V9968 launch/identification, standard comparison and BASIC startup.
- BIOS joining and probe ROM build tools.
- English/Japanese setup and development instructions.
