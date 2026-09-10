param(
    [ValidateSet('fsa1gt','cbios')]
    [string]$Mode = 'fsa1gt',
    [string]$Runtime
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)

function Get-Sha256([string]$Path) {
    if (Get-Command -Name Get-FileHash -ErrorAction SilentlyContinue) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }

    $alg = [System.Security.Cryptography.SHA256]::Create()
    $fs  = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $Path))
    try {
        $bytes = $alg.ComputeHash($fs)
    }
    finally {
        $fs.Dispose()
        $alg.Dispose()
    }

    return ($bytes | ForEach-Object { $_.ToString('X2') }) -join ''
}



if (-not $Runtime) {
    $runtimeBase = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) ('runtime')
    $Runtime = Join-Path $runtimeBase $Mode
}

$Runtime = [IO.Path]::GetFullPath($Runtime)
$cfgPath = Join-Path $Runtime 'config.json'
if (-not (Test-Path -LiteralPath $cfgPath)) {
    throw ('Run setup-' + $Mode + '-v9968.bat first / 対応するセットアップ BAT を実行してください。')
}

$cfg = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json
if ($cfg.mode -ne $Mode) {
    throw 'Runtime mode does not match -Mode. / 指定した機種と環境が一致しません。'
}

$exe = Join-Path $Runtime 'emulator/openmsx.exe'
if ((Get-Sha256 -Path $exe) -ne $cfg.forkSha256) {
    throw 'Emulator hash mismatch. / エミュレーターのハッシュが一致しません。'
}

$romCandidates = @(
    (Join-Path $PSScriptRoot "build/V9968-TECH-DEMO.rom")
    (Join-Path $PSScriptRoot "V9968-TECH-DEMO.rom")
)

$rom = $null
foreach ($candidate in $romCandidates) {
    if (Test-Path -LiteralPath $candidate) {
        $rom = $candidate
        break
    }
}
if (-not $rom) {
    throw 'Demo ROM is missing. Extract the whole ZIP or rebuild. / デモ ROM がありません。ZIP全体を展開するか再ビルドしてください。'
}
if ((Get-Item -LiteralPath $rom).Length -ne 1048576) {
    throw 'Expected a 1 MiB ASCII16-X ROM. / ROM のサイズが不正です。ZIPを再展開するか再ビルドしてください。'
}

$romHash = (Get-Sha256 -Path $rom)
$workRelative = 'user-tech-demo/' + $romHash.Substring(0,12)
$work = Join-Path $Runtime $workRelative
[IO.Directory]::CreateDirectory($work) | Out-Null
$romName = ('V9968-TECH-DEMO-{0}.rom' -f $romHash.Substring(0, 12))
$target = Join-Path $work $romName

if (Test-Path -LiteralPath $target) {
    if ((Get-Sha256 -Path $target) -ne (Get-Sha256 -Path $rom)) {
        throw 'Cached demo ROM hash mismatch. / デモ用 ROM コピーのハッシュが一致しません。'
    }
} else {
    Copy-Item -LiteralPath $rom -Destination $target
}

$saved = @{}
foreach ($v in @('OPENMSX_HOME','OPENMSX_USER_DATA','OPENMSX_SYSTEM_DATA')) {
    $saved[$v] = [Environment]::GetEnvironmentVariable($v, 'Process')
}

try {
    $env:OPENMSX_HOME = $workRelative + '/home'
    $env:OPENMSX_USER_DATA = $workRelative + '/home/share'
    $env:OPENMSX_SYSTEM_DATA = 'emulator/share'

    if ($Mode -eq 'fsa1gt') {
        $dir = Join-Path $work 'home/share/systemroms'
        [IO.Directory]::CreateDirectory($dir) | Out-Null
        foreach ($name in @('fs-a1gt_firmware.rom', 'fs-a1gt_kanjifont.rom')) {
            $src = Join-Path $Runtime ('bios/{0}' -f $name)
            $dst = Join-Path $dir $name
            if (Test-Path -LiteralPath $dst) {
                if ((Get-Sha256 -Path $src) -ne (Get-Sha256 -Path $dst)) {
                    throw 'Local BIOS copy differs; use a new demo user folder. / デモ用 BIOS コピーが元データと異なります。別のデモ用フォルダを使用してください。'
                }
            }
            else {
                Copy-Item -LiteralPath $src -Destination $dst
            }
        }
    }

    $arg = @(
        '-machine', $cfg.machine,
        '-cart', ($workRelative + '/' + $romName),
        '-romtype', 'ASCII16-X'
    )
    $p = Start-Process -FilePath $exe -ArgumentList $arg -WorkingDirectory $Runtime -WindowStyle Normal -PassThru
    $null = $p.Handle
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) {
        throw 'openMSX exited with an error. / openMSX がエラーで終了しました。'
    }
}
finally {
    foreach ($v in $saved.Keys) {
        [Environment]::SetEnvironmentVariable($v, $saved[$v], 'Process')
    }
}
