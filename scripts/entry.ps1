param(
 [ValidateSet('Setup','Launch','Verify','Basic','Join','Build')][string]$Action='Launch',
 [ValidateSet('cbios','fsa1gt')][string]$Mode='cbios',
 [string]$InputDir,[string]$OutputDir,[string]$CacheDir,[switch]$Standard,[string]$Z88dk,[switch]$SelectZ88dk
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
try {
 switch($Action){
  Setup {
   $opts=@{Mode=$Mode}
   if($InputDir){$opts.BiosDir=$InputDir}
   if($CacheDir){$opts.CacheDir=$CacheDir}
   & (Join-Path $PSScriptRoot 'setup.ps1') @opts
  }
  Build { & (Join-Path $PSScriptRoot 'build-probe.ps1') -Z88dk $Z88dk -SelectZ88dk:$SelectZ88dk }
  Join {
   if(!$InputDir){
    Add-Type -AssemblyName System.Windows.Forms
    $d=New-Object Windows.Forms.FolderBrowserDialog
    $d.Description='Select the folder with 32 A1GTFIRM parts and the Kanji ROM / ダンプを保存したフォルダを選択'
    try {if($d.ShowDialog() -ne 'OK'){throw 'Cancelled / キャンセルしました。'};$InputDir=$d.SelectedPath}finally{$d.Dispose()}
   }
   if(!$OutputDir){$OutputDir=Join-Path $repo 'private/fsa1gt-bios'}
   & (Join-Path $PSScriptRoot 'join-fsa1gt-dump.ps1') -DumpDir $InputDir -OutputDir $OutputDir
   Write-Host 'Next / 次: drag the output folder onto setup-fsa1gt-v9968.bat / 出力フォルダをセットアップ BAT へドラッグしてください。'
  }
  default {
   $dir=Join-Path $repo "runtime/$Mode"
   if(!(Test-Path -LiteralPath (Join-Path $dir 'installation.json'))){throw "Not installed / 未セットアップです。Run / 実行: setup-$Mode-v9968.bat"}
   $options=@{}
   if($Action -eq 'Verify'){$options.Verify=$true}
   if($Action -eq 'Basic'){$options.Basic=$true}
   if($Standard){$options.Standard=$true}
   & (Join-Path $dir 'launch.ps1') @options
  }
 }
} catch { Write-Host "Error / エラー: $($_.Exception.Message)"; exit 1 }
