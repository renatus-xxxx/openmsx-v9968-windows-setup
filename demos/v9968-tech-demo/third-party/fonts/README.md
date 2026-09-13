[日本語](README.ja.md)

# HUD fonts


- **MSX 8x8 font**, 1re1: [author-published MSXPen source](https://msxpen.com/codes/-Nq8q6wabU6mJ4onDmYE), linked by the [author announcement](https://twitter.com/1re1). `msx8x8-ascii.asm` preserves the PGT1/PGT2 data excerpt. The author's stated condition is free use provided it does not offend public order and morals; this is not a repository-wide license grant. See also the [font gallery](https://gigamix.hatenablog.com/entry/devmsx/msx-font-gallery).

Checked 2026-09-10. `sources.json` records locally calculated SHA-256 hashes. MSX8x8 uses ASCII glyphs.

Run `python generate-fonts.py` from the demo directory (also run automatically by `build.ps1`). It converts upstream rows to `assets/fonts.json`. `generate-megarom.py` uses this single data source for both the title and scene labels. The title and scene labels are composed into shadowed header strips in the HUDLINE ROM asset. Each frame overlays its strip onto the finished picture; the Scene 3 background beneath the stationary text remains distorted. Original background PNGs remain editable and unchanged.
