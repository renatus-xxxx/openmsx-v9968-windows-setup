[日本語](publishing.ja.md) | English

# Maintainer publishing instructions

Repository name: openmsx-v9968-windows-setup

Description:
> Unofficial Windows setup scripts for the V9968-enabled openMSX fork, with C-BIOS and user-supplied FS-A1GT BIOS support.

Review the [public allowlist](../config/PUBLIC_FILES.txt), [licenses](sources.md) and [release notes](release-notes.md).

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1
```

The ZIP contains only allowlisted files, without an enclosing folder. Default output: dist/openmsx-v9968-windows-setup-0.5.0.zip. Existing ZIPs are not overwritten.

Do not add runtime, cache, private, build, dist or owned BIOS to Git. The only published ROM is the custom probe/PROBE.rom application. Check Git's selected files and archive contents before publication. Preserve original third-party notices.

config/PUBLIC_FILES.txt limits the files included in distribution. It is included in both the repository and ZIP so either can regenerate the package. See the [changelog](CHANGELOG.md).

LICENSE stays unchanged at the root, following the conventional location described by [GitHub's licensing guide](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

.gitattributes stays at the root to apply across the tree: CRLF for BAT/PowerShell, LF for Markdown, and binary handling for ROM/PNG. It does not specify encoding or BOM. ZIP extraction does not apply Git attributes, but the file is included for subsequent Git use. See the [official Git specification](https://git-scm.com/docs/gitattributes). References checked 2026-09-09.

## Command behavior and check coverage

Run from the repository root. `-NoProfile` skips personal PowerShell profiles; `-ExecutionPolicy Bypass` sets the policy for this process without changing the persistent policy.

- `validate-public.ps1`: checks the public allowlist for duplicates, missing files and prohibited paths; paired documents and local links; the four root BATs and helper references; and the probe ROM hash. Supply `-ZipPath` to check an existing ZIP as well.
- `package.ps1`: runs those checks, creates a Releases asset ZIP containing only allowlisted files, compares its entries with the source files, and prints SHA-256. It refuses to overwrite an existing output ZIP.

Validation uses `config/PUBLIC_FILES.txt`. It also rejects paths outside the root, prohibited installation/generated files and ROMs other than the custom probe, and checks specific personal-path/content patterns in text. It checks top language links in paired documents and BAT references to entry.ps1.

With `-ZipPath`, it compares ZIP paths, duplicates and file count against the allowlist, and each entry's SHA-256 against its source file. Without this option it does not inspect an existing ZIP. These static checks do not check external URL availability, detect every possible secret or personal detail, execute the emulator, or inspect Git history. Review the public files and Git diff separately.

Packaging derives the default ZIP name from the release field in `config/versions.json`. Use `-OutputZip` for another output path. Preserve an existing ZIP outside the repository or choose another filename.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1 -ZipPath dist\openmsx-v9968-windows-setup-0.5.0.zip
```

## Distribution through GitHub Releases

1. Prepare the validated `dist/openmsx-v9968-windows-setup-0.5.0.zip` as the release asset. `dist/` is local output and stays outside Git tracking.
2. After reviewing the final commit, the maintainer selects the target commit, tag `v0.5.0`, title `0.5.0`, and English/Japanese release text on the release creation page.
3. Attach the ZIP, check its name, contents and SHA-256, then publish. Do not confuse it with the Source code archives.
4. After publication, follow the README links and confirm that the downloaded ZIP's SHA-256 matches the final local ZIP.

This preparation task does not commit, push, create tags or create a release. Before publication, the ZIP link is not yet available.
