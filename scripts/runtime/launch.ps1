param([switch]$Standard,[switch]$Verify,[switch]$Basic)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)
Set-StrictMode -Version 2
$root=$PSScriptRoot
$saved=@{}
$vars=@('OPENMSX_HOME','OPENMSX_USER_DATA','OPENMSX_SYSTEM_DATA','V9968_TEST_LOG','V9968_EXPECT_ID')
foreach($v in $vars){$saved[$v]=[Environment]::GetEnvironmentVariable($v,'Process')}
Push-Location $root
try {
    $cfg=Get-Content -LiteralPath (Join-Path $root 'config.json') -Raw | ConvertFrom-Json
    if($Basic -and $cfg.mode -ne 'fsa1gt'){throw 'この C-BIOS 構成は BASIC を提供しません。'}
    if($Basic -and $Verify){throw 'Basic と Verify は同時指定できません。'}
    $kind=if($Verify){'selftest'}elseif($Standard){'standard'}else{'v9968'}
    # Official 21.0 cannot resolve Japanese absolute data paths reliably.
    # Use ASCII relative names with an explicit Unicode-capable process working directory.
    $env:OPENMSX_HOME="user-$kind"
    $env:OPENMSX_USER_DATA="user-$kind/share"
    $env:OPENMSX_SYSTEM_DATA='emulator/share'
    $exe=Join-Path $root $(if($Standard){'emulator/openmsx-standard.exe'}else{'emulator/openmsx.exe'})
    $expected=if($Standard){$cfg.standardSha256}else{$cfg.forkSha256}
    if((Get-FileHash -LiteralPath $exe).Hash -ne $expected){throw 'openMSX 実行ファイルの SHA-256 が一致しません。'}
    $probe=Join-Path $root 'probe/PROBE.rom'
    if((Get-FileHash -LiteralPath $probe).Hash -ne $cfg.probeSha256){throw '確認 ROM が変更されています。'}
    $machine=if($Standard){$cfg.standardMachine}else{$cfg.machine}
    $argv=@('-machine',$machine)
    if(!$Basic){$argv+=@('-cart','probe/PROBE.rom')}
    if($Verify){
        $logs=Join-Path $root 'logs'
        [IO.Directory]::CreateDirectory($logs) | Out-Null
        $tag=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
        $env:V9968_TEST_LOG="logs/$tag-result.txt"
        $env:V9968_EXPECT_ID=if($Standard){'2'}else{'3'}
        $argv+=@('-script','verify.tcl')
        $p=Start-Process -FilePath $exe -ArgumentList $argv -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs "$tag-stdout.txt") -RedirectStandardError (Join-Path $logs "$tag-stderr.txt")
        $processHandle=$p.Handle
        if(!$p.WaitForExit(60000)){$p.Kill(); $p.WaitForExit(); throw "起動テストが60秒で完了しません。ログ: $logs"}
        if($p.ExitCode -ne 0){throw "openMSX 起動失敗 (終了コード $($p.ExitCode))。ログ: $logs"}
        if(!(Test-Path -LiteralPath $env:V9968_TEST_LOG)){throw "確認結果を取得できません。DLL・画面ドライバー・ROM を確認してください。ログ: $logs"}
        $result=Get-Content -LiteralPath $env:V9968_TEST_LOG -Raw
        if($result -notmatch 'SELFTEST=PASS'){throw "C プログラムの VDP ID が期待値と異なります。ログ: $logs"}
        Write-Host "起動確認 OK: $machine / VDP ID=$env:V9968_EXPECT_ID"
        Write-Host "結果と画像: $(Join-Path $root $env:V9968_TEST_LOG)"
    } else {
        $p=Start-Process -FilePath $exe -ArgumentList $argv -WorkingDirectory $root -WindowStyle Normal -Wait -PassThru
        if($p.ExitCode -ne 0){throw "openMSX の終了コード: $($p.ExitCode)"}
    }
} finally {
    Pop-Location
    foreach($v in $vars){[Environment]::SetEnvironmentVariable($v,$saved[$v],'Process')}
}
