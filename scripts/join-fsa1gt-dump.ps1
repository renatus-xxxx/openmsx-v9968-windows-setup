param([Parameter(Mandatory=$true)][string]$DumpDir,[Parameter(Mandatory=$true)][string]$OutputDir)
$ErrorActionPreference='Stop'
# Only reads dump files. Never patches bytes or overwrites an existing output.
$DumpDir=(Resolve-Path -LiteralPath $DumpDir).Path
$OutputDir=[IO.Path]::GetFullPath($OutputDir)
if(Test-Path -LiteralPath $OutputDir){throw '出力フォルダは未作成のパスを指定してください。既存ファイルを保護するため停止します。'}
$spec=Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'config/versions.json') -Raw | ConvertFrom-Json
$parts=@(for($i=0;$i -lt 32;$i++){
    $name='A1GTFIRM.{0:X3}' -f $i
    $p=Join-Path $DumpDir $name
    if(!(Test-Path -LiteralPath $p -PathType Leaf) -or (Get-Item -LiteralPath $p).Length -ne 131072){throw "不足またはサイズ不一致: $name（131072 bytes が必要）"}
    $p
})
$fonts=@(foreach($name in @('A1GTKFN.ROM','KANJI.ROM','fs-a1gt_kanjifont.rom')){
    $p=Join-Path $DumpDir $name
    if(Test-Path -LiteralPath $p -PathType Leaf){
        if((Get-Item -LiteralPath $p).Length -ne 262144){throw "漢字 ROM のサイズ不一致: $name"}
        $sha=(Get-FileHash -LiteralPath $p -Algorithm SHA1).Hash
        if($spec.bios[1].sha1 -notcontains $sha){throw "漢字 ROM の SHA-1 が対応値と異なります: $name / $sha"}
        $p
    }
})
if(!$fonts.Count){throw 'A1GTKFN.ROM または KANJI.ROM（256 KiB）が必要です。'}
$buf=New-Object IO.MemoryStream
try {
    foreach($p in $parts){$b=[IO.File]::ReadAllBytes($p);$buf.Write($b,0,$b.Length)}
    $firm=$buf.ToArray()
}finally{$buf.Dispose()}
$hasher=[Security.Cryptography.SHA1]::Create()
try {$sha=([BitConverter]::ToString($hasher.ComputeHash($firm))).Replace('-','')}finally{$hasher.Dispose()}
if($spec.bios[0].sha1 -notcontains $sha){throw "結合結果の SHA-1 が対応値と異なります: $sha。順序・転送・実機の版を確認してください。出力せず停止します。"}
$fontBytes=[IO.File]::ReadAllBytes($fonts[0])
$hasher=[Security.Cryptography.SHA1]::Create()
try {$fontSha=([BitConverter]::ToString($hasher.ComputeHash($fontBytes))).Replace('-','')}finally{$hasher.Dispose()}
if($spec.bios[1].sha1 -notcontains $fontSha){throw '読取り中に漢字 ROM が変更されました。'}
New-Item -ItemType Directory -Path $OutputDir -ErrorAction Stop | Out-Null
foreach($entry in @(@('fs-a1gt_firmware.rom',$firm),@('fs-a1gt_kanjifont.rom',$fontBytes))){
    $s=[IO.File]::Open((Join-Path $OutputDir $entry[0]),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {$s.Write($entry[1],0,$entry[1].Length)}finally{$s.Dispose()}
}
Write-Host "作成完了: $OutputDir"
Get-ChildItem -LiteralPath $OutputDir -File | Get-FileHash -Algorithm SHA1
