$ErrorActionPreference="Continue"
"=== SRV-EXE FORENSICS START {0} ===" -f (Get-Date -Format "HH:mm:ss")
$rel="D:\p100-llama-cpp\llama.cpp\build\bin\Release"
$p=Join-Path $rel "llama-server.exe"
$fi=Get-Item $p -Force
"size={0}  created={1}  modified={2}" -f $fi.Length,$fi.CreationTime,$fi.LastWriteTime
$b=[IO.File]::ReadAllBytes($p)
"first16=" + (($b[0..([math]::Min(15,$b.Length-1))] | ForEach-Object { $_.ToString("X2") }) -join " ")
$isMZ=($b.Length -ge 2 -and $b[0] -eq 0x4D -and $b[1] -eq 0x5A)
$isLNK=($b.Length -ge 4 -and $b[0] -eq 0x4C -and $b[1] -eq 0x00)
"isMZ=$isMZ  isLNK=$isLNK"
$printable=-join ($b | ForEach-Object { if($_ -ge 32 -and $_ -le 126){ [char]$_ } else { "." } })
"content=[$printable]"
"== collateral sweep: Release files modified since 10-19 =="
Get-ChildItem $rel -File | Where-Object { $_.LastWriteTime -gt [datetime]"2026-10-19 00:00" } | ForEach-Object { "{0}  {1}  {2}" -f $_.LastWriteTime,$_.Length,$_.Name }
"== binary identity sweep =="
foreach($n in @("llama.dll","ggml-cuda.dll","ggml.dll","ggml-base.dll","llama-cli.exe","test-backend-ops.exe")){
  $q=Join-Path $rel $n
  if(Test-Path $q){ $z=Get-Item $q; "{0,-22} {1,12}  {2}" -f $z.Name,$z.Length,$z.LastWriteTime } else { "$n MISSING" }
}
"== git state =="
cmd /c "git -C D:\p100-llama-cpp status --short"
cmd /c "git -C D:\p100-llama-cpp log --oneline -3"
"tracked?(empty=no):"
cmd /c "git -C D:\p100-llama-cpp ls-files -- llama.cpp/build/bin/Release/llama-server.exe"
"== backup hunt =="
foreach($d in @("D:\r26bin_keep","D:\p0_evidence","D:\r26bin_old","D:\temp\bin_old","D:\p100-llama-cpp\llama.cpp\build\bin\bin_old")){
  if(Test-Path $d){
    Get-ChildItem $d -Recurse -Filter "llama-server.exe" -ErrorAction SilentlyContinue | Select-Object -First 3 | ForEach-Object { "{0}  {1}  {2}" -f $_.FullName,$_.Length,$_.LastWriteTime }
  } else { "absent: $d" }
}
"== PSReadLine history tail (PS 侧 10:10 前后线索；cmd 会话历史不留痕) =="
$h=Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
if(Test-Path $h){ Get-Content $h -Tail 50 } else { "no psreadline history" }
"=== SRV-EXE FORENSICS DONE {0} ===" -f (Get-Date -Format "HH:mm:ss")