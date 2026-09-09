# Requires Windows PowerShell 5.1; UTF-8 BOM is intentional.
param(
    [ValidateSet('cbios','fsa1gt')][string]$Mode='cbios',
    [string]$BiosDir,
    [string]$Destination,
    [string]$CacheDir
)
$RepoRoot=Split-Path -Parent $PSScriptRoot
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)
Set-StrictMode -Version 2
$lock=$null; $log=$null; $stage=$null
function Say([string]$Text) {
    Write-Host $Text
    if($script:log){Add-Content -LiteralPath $script:log -Value $Text -Encoding UTF8}
}
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function CheckHash([string]$Path,[string]$Expected) {
    if(!(Test-Path -LiteralPath $Path -PathType Leaf) -or (Hash $Path) -ne $Expected){throw "SHA-256 mismatch or missing file / ファイルの SHA-256 が不一致、または不足: $Path"}
}
function MakeDir([string]$Path) { [IO.Directory]::CreateDirectory($Path) | Out-Null }
function WriteUtf8([string]$Path,[string]$Text) { [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($true))) }
function CheckReparse([string]$Path) {
    $p=$Path
    while($p){
        if(Test-Path -LiteralPath $p){
            if((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Destination contains a link or junction, which is not supported / リンク・ジャンクションを含む配置先は使用できません: $p"}
        }
        $p=Split-Path -Parent $p
    }
}
function FindBios([string]$Dir,$Specs) {
    if(!(Test-Path -LiteralPath $Dir -PathType Container)){throw "BIOS folder not found / BIOS フォルダが見つかりません: $Dir"}
    $items=New-Object 'System.Collections.Generic.List[object]'
    $queue=New-Object 'System.Collections.Generic.Queue[string]'
    $queue.Enqueue((Get-Item -LiteralPath $Dir).FullName)
    while($queue.Count){
        foreach($i in Get-ChildItem -LiteralPath $queue.Dequeue() -Force){
            if($i.Attributes -band [IO.FileAttributes]::ReparsePoint){continue}
            if($i.PSIsContainer){$queue.Enqueue($i.FullName)}
            elseif($Specs.size -contains $i.Length){$items.Add($i)}
        }
    }
    $selected=@()
    foreach($spec in $Specs){
        $matches=@(foreach($i in $items){
            if($i.Length -eq $spec.size){
                $sha1=(Get-FileHash -LiteralPath $i.FullName -Algorithm SHA1).Hash
                if($spec.sha1 -contains $sha1){[pscustomobject]@{file=$i.FullName;sha1=$sha1;name=$spec.name;sha256=(Hash $i.FullName)}}
            }
        })
        if(!$matches.Count){throw "BIOS missing or unknown version: $($spec.name) / $($spec.size) bytes. A combined ROM whose SHA-1 matches versions.json is required; split dumps are not joined here. Run tools\bios\join-fsa1gt-dump.bat first.`n対応 BIOS が不足または未知の版です: $($spec.name) / $($spec.size) bytes。versions.json の SHA-1 と一致する統合 ROM が必要です。分割ダンプは先に tools\bios\join-fsa1gt-dump.bat で結合してください。"}
        if(@($matches.sha1 | Select-Object -Unique).Count -gt 1){throw "Multiple supported BIOS versions found: $($spec.name). Copy only the pair you want into a separate folder and specify that folder.`n複数の対応 BIOS 版が見つかりました: $($spec.name)。使用する一組だけを別フォルダへコピーして指定してください。"}
        if($matches.Count -gt 1){Say "Duplicate identical BIOS files found; copying one / 同一内容の BIOS が複数あります。1個をコピーします: $($spec.name)"}
        $selected+=$matches[0]
        Say "BIOS verified / BIOS 照合 OK: $($spec.name) / SHA-1=$($matches[0].sha1)"
    }
    return $selected
}
function Download($Spec,[string]$Cache) {
    $target=Join-Path $Cache $Spec.file
    if(Test-Path -LiteralPath $target){
        if((Get-Item -LiteralPath $target).Length -ne $Spec.size){throw "Cached file has the wrong size: $target. Move it aside under another name and run setup again.`nキャッシュのサイズ不一致: $target。別名へ移して再実行してください。"}
        CheckHash $target $Spec.sha256
        Say "Reusing verified cache / 検証済みキャッシュを再利用: $($Spec.file)"
        return $target
    }
    if(!([uri]$Spec.url).IsAbsoluteUri -or ([uri]$Spec.url).Scheme -ne 'https'){throw 'An HTTPS download URL is required / HTTPS の配布 URL が必要です。'}
    $part="$target.$([guid]::NewGuid().ToString('N')).part"
    Say "Downloading / ダウンロード: $($Spec.url)"
    $oldPreference=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue' # Windows PowerShell wraps native stderr in ErrorRecord.
        & $script:curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --connect-timeout 20 --max-time 300 --retry 2 --output $part $Spec.url 2>> $script:log
        $rc=$LASTEXITCODE
    } finally {$ErrorActionPreference=$oldPreference}
    if($rc -ne 0){throw "curl failed (exit code $rc). Check your network, proxy settings and the download source. Incomplete file: $part`ncurl 失敗 (終了コード $rc)。通信・プロキシ・配布元を確認してください。不完全ファイル: $part"}
    if((Get-Item -LiteralPath $part).Length -ne $Spec.size){throw "Downloaded size does not match / ダウンロードサイズ不一致: $part"}
    CheckHash $part $Spec.sha256
    Move-Item -LiteralPath $part -Destination $target
    return $target
}
function ExpandChecked([string]$Zip,[string]$To) {
    # Reject absolute paths / traversal before extracting even a hash-verified archive.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $a=[IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        $prefix=[IO.Path]::GetFullPath($To).TrimEnd('\')+'\'
        foreach($entry in $a.Entries){
            $name=$entry.FullName.Replace('/','\')
            if([IO.Path]::IsPathRooted($name) -or $name.Contains(':') -or !([IO.Path]::GetFullPath((Join-Path $To $name))).StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'The ZIP contains an unsafe path; extraction stopped / ZIP に不正なパスがあります。展開を中止しました。'}
        }
    } finally {$a.Dispose()}
    MakeDir $To
    [IO.Compression.ZipFile]::ExtractToDirectory($Zip,$To)
}
function CheckExisting([string]$Root,$Manifest) {
    $receiptPath=Join-Path $Root 'installation.json'
    if(!(Test-Path -LiteralPath $receiptPath)){throw "The existing folder has no installation record. Stopping instead of overwriting it; specify a different destination.`n既存フォルダに管理記録がありません。上書きせず停止します。別の配置先を指定してください。"}
    $receipt=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    if($receipt.mode -ne $Mode -or $receipt.manifestSha256 -ne (Hash (Join-Path $RepoRoot 'config/versions.json'))){throw "The existing installation has a different mode or version. Specify a different destination.`n既存環境のモード・版が違います。別の配置先を指定してください。"}
    foreach($file in $receipt.files){
        $p=[IO.Path]::GetFullPath((Join-Path $Root $file.path))
        if(!$p.StartsWith($Root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'The installation record contains an invalid path / 管理記録のパスが不正です。'}
        CheckReparse $p
        CheckHash $p $file.sha256
    }
    # Also verify the trusted entry points against the current distribution.
    CheckHash (Join-Path $Root 'emulator/openmsx.exe') $Manifest.forkExeSha256
    CheckHash (Join-Path $Root 'emulator/openmsx-standard.exe') $Manifest.officialExeSha256
    CheckHash (Join-Path $Root 'probe/PROBE.rom') $Manifest.probeSha256
    foreach($rel in @('launch.ps1','verify.tcl')){CheckHash (Join-Path $Root $rel) (Hash (Join-Path $RepoRoot "scripts/runtime/$rel"))}
}
try {
    if(![Environment]::Is64BitOperatingSystem -or [Environment]::OSVersion.Version.Major -lt 10){throw 'Windows 10/11 x64 is required / Windows 10/11 x64 が必要です。'}
    if($PSVersionTable.PSVersion -lt [version]'5.1'){throw 'Windows PowerShell 5.1 or later is required / Windows PowerShell 5.1 以上が必要です。'}
    $m=Get-Content -LiteralPath (Join-Path $RepoRoot 'config/versions.json') -Raw | ConvertFrom-Json
    if(!$Destination){$Destination=Join-Path $RepoRoot "runtime/$Mode"}
    $Destination=[IO.Path]::GetFullPath($Destination).TrimEnd('\')
    if(!$CacheDir){$CacheDir=Join-Path $RepoRoot 'cache'}
    $CacheDir=[IO.Path]::GetFullPath($CacheDir)
    CheckReparse $Destination; CheckReparse $CacheDir
    $parent=Split-Path -Parent $Destination
    if(!$parent -or $Destination -eq [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')){throw "Choose a dedicated subfolder, not the folder that holds the setup files.`nセットアップ資料と異なる専用サブフォルダを指定してください。"}
    MakeDir $parent
    $logs=Join-Path $parent 'setup-logs'; MakeDir $logs
    $log=Join-Path $logs ("{0}-{1}-{2}.log" -f $Mode,(Get-Date -Format 'yyyyMMdd-HHmmss'),$PID)
    Say "V9968 setup / V9968 セットアップ $($m.release) / $Mode"
    Say "Destination / 配置先: $Destination"
    # OS handle lock is released even after an interrupted run; never remove other locks.
    $lock=[IO.File]::Open("$Destination.setup.lock",[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    if(Test-Path -LiteralPath $Destination){
        CheckExisting $Destination $m
        Say "The managed files of the existing installation match. Keeping your settings and reusing it.`n既存環境の管理ファイルは一致しています。ユーザー設定を保持して再利用します。"
    } else {
        $bios=@()
        if($Mode -eq 'fsa1gt'){
            if(!$BiosDir){
                Add-Type -AssemblyName System.Windows.Forms
                $dialog=New-Object Windows.Forms.FolderBrowserDialog
                $dialog.Description='Select the FS-A1GT BIOS folder you are entitled to use (nothing is uploaded) / 利用権限を確認した FS-A1GT BIOS フォルダを指定してください（外部送信しません）。'
                try {if($dialog.ShowDialog() -ne 'OK'){throw 'BIOS folder selection cancelled / BIOS フォルダの選択がキャンセルされました。'}; $BiosDir=$dialog.SelectedPath} finally {$dialog.Dispose()}
            }
            $bios=@(FindBios $BiosDir $m.bios)
        }
        CheckHash (Join-Path $RepoRoot 'probe/PROBE.rom') $m.probeSha256
        $curl=Join-Path $env:SystemRoot 'System32/curl.exe'
        if(![Environment]::Is64BitProcess){$curl=Join-Path $env:SystemRoot 'Sysnative/curl.exe'}
        if(!(Test-Path -LiteralPath $curl)){throw "The built-in Windows curl.exe was not found. Apply Windows Update.`nWindows 標準 curl.exe がありません。Windows Update を適用してください。"}
        MakeDir $CacheDir
        $zips=@(foreach($spec in $m.downloads){Download $spec $CacheDir})
        $stage=Join-Path $parent ('.'+(Split-Path -Leaf $Destination)+'.staging-'+[guid]::NewGuid().ToString('N'))
        MakeDir $stage
        ExpandChecked $zips[0] (Join-Path $stage 'emulator')
        ExpandChecked $zips[1] (Join-Path $stage 'fork-download')
        $emu=Join-Path $stage 'emulator'
        CheckHash (Join-Path $emu 'openmsx.exe') $m.officialExeSha256
        CheckHash (Join-Path $stage 'fork-download/openmsx.exe') $m.forkExeSha256
        Move-Item -LiteralPath (Join-Path $emu 'openmsx.exe') -Destination (Join-Path $emu 'openmsx-standard.exe')
        Copy-Item -LiteralPath (Join-Path $stage 'fork-download/openmsx.exe') -Destination (Join-Path $emu 'openmsx.exe')
        $standard=if($Mode -eq 'cbios'){'C-BIOS_MSX2+_JP'}else{'Panasonic_FS-A1GT'}
        $machine=if($Mode -eq 'cbios'){'C-BIOS_V9968_JP'}else{'Panasonic_FS-A1GT_V9968'}
        $xmlPath=Join-Path $emu "share/machines/$standard.xml"
        $xml=Get-Content -LiteralPath $xmlPath -Raw
        $pattern='(?s)<VDP id="VDP">.*?</VDP>'
        if([regex]::Matches($xml,$pattern).Count -ne 1){throw 'The machine XML structure is not as expected; setup stopped / 機種 XML の構造が想定と異なります。処理を中止しました。'}
        $vdp='<VDP id="VDP"><version>V9968</version><vram>128</vram><io base="0x98" num="5" type="O"/><io base="0x98" num="5" type="I"/><timing>0</timing></VDP>'
        $xml=[regex]::Replace($xml,$pattern,$vdp)
        $xml=$xml.Replace('</code>',' V9968 experiment</code>')
        $xml=$xml.Replace('<msxconfig>','<msxconfig><!-- Derived from official openMSX 21.0. Modified 2026-09-09: VDP block and display name for V9968. GPL; see doc/GPL.txt. -->')
        # openMSX 21's machine XML reader rejects a UTF-8 BOM.
        [IO.File]::WriteAllText((Join-Path $emu "share/machines/$machine.xml"),$xml,(New-Object Text.UTF8Encoding($false)))
        MakeDir (Join-Path $stage 'bios')
        foreach($b in $bios){
            $copy=Join-Path $stage "bios/$($b.name)"
            Copy-Item -LiteralPath $b.file -Destination $copy
            CheckHash $copy $b.sha256
        }
        MakeDir (Join-Path $stage 'probe')
        Copy-Item -LiteralPath (Join-Path $RepoRoot 'probe/PROBE.rom') -Destination (Join-Path $stage 'probe/PROBE.rom')
        foreach($name in @('launch.ps1','verify.tcl')){Copy-Item -LiteralPath (Join-Path $RepoRoot "scripts/runtime/$name") -Destination (Join-Path $stage $name)}
        # Let both dedicated user homes find BIOS without changing systemroms globally.
        foreach($kind in @('v9968','standard','selftest')){
            MakeDir (Join-Path $stage "user-$kind/share/systemroms")
            foreach($b in $bios){Copy-Item -LiteralPath (Join-Path $stage "bios/$($b.name)") -Destination (Join-Path $stage "user-$kind/share/systemroms/$($b.name)")}
        }
        $config=[ordered]@{mode=$Mode;machine=$machine;standardMachine=$standard;forkSha256=$m.forkExeSha256;standardSha256=$m.officialExeSha256;probeSha256=$m.probeSha256}
        WriteUtf8 (Join-Path $stage 'config.json') ($config | ConvertTo-Json)
        foreach($entry in @(@('launch-v9968.bat',''),@('launch-standard.bat',' -Standard'),@('verify-v9968.bat',' -Verify'),@('launch-basic.bat',' -Basic'))){
            if($Mode -eq 'cbios' -and $entry[0] -eq 'launch-basic.bat'){continue}
            $bat="@echo off`r`nsetlocal DisableDelayedExpansion`r`nchcp 65001 >nul`r`nset `"PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules`"`r`n`"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`" -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"%~dp0launch.ps1`"$($entry[1])`r`nset `"rc=%errorlevel%`"`r`npause`r`nexit /b %rc%`r`n"
            [IO.File]::WriteAllText((Join-Path $stage $entry[0]),$bat,[Text.Encoding]::ASCII)
        }
        Say 'Running the boot test with the probe ROM (up to 60 seconds) / 確認 ROM による起動テストを実行します（最大60秒）。'
        & (Join-Path $stage 'launch.ps1') -Verify
        # Include system binaries, machine definitions and local BIOS in the immutable record.
        # User settings and logs are deliberately excluded and never overwritten on rerun.
        $files=@(Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object {
            $rel=$_.FullName.Substring($stage.Length+1)
            if($rel -notmatch '^(user-|logs[\\/])' -or $rel -match '^user-[^\\/]+[\\/]share[\\/]systemroms[\\/].+\.rom$'){
                [ordered]@{path=$rel;sha256=(Hash $_.FullName)}
            }
        })
        $receipt=[ordered]@{release=$m.release;mode=$Mode;created=(Get-Date -Format o);manifestSha256=(Hash (Join-Path $RepoRoot 'config/versions.json'));files=$files}
        WriteUtf8 (Join-Path $stage 'installation.json') ($receipt | ConvertTo-Json -Depth 6)
        Move-Item -LiteralPath $stage -Destination $Destination
        $stage=$null
    }
    Say "Done / 完了: $Destination"
    Say "Launch / 起動: $(Join-Path $RepoRoot ('launch-'+$Mode+'-v9968.bat'))"
    Say "Verify / 確認: $(Join-Path $RepoRoot ('tools/verify/verify-'+$Mode+'-v9968.bat'))"
    Say "Log / ログ: $log"
} catch {
    Say "Failed / 失敗: $($_.Exception.Message)"
    if($stage){Say "Kept the incomplete staging folder; the next run creates a new one / 未完成の作業フォルダを保持しました（次回は新規作成します）: $stage"}
    if($log){Say "Log / ログ: $log"}
    exit 1
} finally {if($lock){$lock.Dispose()}}
