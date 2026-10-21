$ErrorActionPreference='Stop'
$HDR = @{ Authorization = 'Bearer sk-av3IfMH0FtRoc8rDjYdkA4xJVXKnB5wsUTeLbGWZ' }
$REQ = '{"messages":[{"role":"system","content":"你是一位中文文学创作者。"},{"role":"user","content":"以旧书摊的黄昏为题写一段散文，约两百字。"}],"temperature":0.8,"top_p":0.95,"top_k":40,"min_p":0.05,"seed":42,"max_tokens":256,"stream":false,"cache_prompt":false}'
function Invoke-Run([int]$sw,[int]$idx){
  cmd /c "taskkill /IM llama-server.exe /F >nul 2>&1"; cmd /c "ping -n 15 127.0.0.1 >nul"
  $srv = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','D:\temp\p16_sw.bat',"$sw" -RedirectStandardOutput "D:\temp\r13srv_$idx.log" -RedirectStandardError "D:\temp\r13srv_$idx.err.log" -PassThru
  try {
    $ok=$false
    foreach($i in 1..1500){
      try { $r=Invoke-WebRequest 'http://127.0.0.1:8080/health' -Headers $HDR -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200){$ok=$true;break} } catch {}
      Start-Sleep -Seconds 1
    }
    if(-not $ok){ throw "run$idx sw=$sw health 超时，看 D:\temp\r13srv_$idx.log" }
    Write-Host "run$idx sw=$sw server ready, firing..."
    $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/chat/completions' -Method Post -Headers $HDR -Body ([Text.Encoding]::UTF8.GetBytes($REQ)) -ContentType 'application/json; charset=utf-8' -TimeoutSec 600
    $c = $resp.choices[0].message.content
    if ([string]::IsNullOrWhiteSpace($c)) { $c = $resp.choices[0].message.reasoning_content }
    if ([string]::IsNullOrWhiteSpace($c)) { throw "run$idx 内容空" }
    if ($resp.timings.predicted_n -lt 256) { throw "run$idx tokens=$($resp.timings.predicted_n)<256" }
    [IO.File]::WriteAllText("D:\temp\r13_run${idx}_content.txt", $c, (New-Object Text.UTF8Encoding($false)))
    $tg = [math]::Round($resp.timings.predicted_per_second,3)
    $hash = (Get-FileHash "D:\temp\r13_run${idx}_content.txt").Hash
    Write-Host ("run{0} sw={1}  tg={2}  tokens={3}  chars={4}" -f $idx,$sw,$tg,$resp.timings.predicted_n,$c.Length)
    [pscustomobject]@{ sw=$sw; tg=$tg; hash=$hash }
  } finally {
    cmd /c "taskkill /IM llama-server.exe /F >nul 2>&1"
    if($srv -and -not $srv.HasExited){ Stop-Process -Id $srv.Id -Force }
    cmd /c "ping -n 15 127.0.0.1 >nul"
  }
}
$r1 = Invoke-Run 1 1
$r2 = Invoke-Run 0 2
$r3 = Invoke-Run 0 3
$r4 = Invoke-Run 1 4
$aTg = ($r1.tg + $r4.tg)/2
$bTg = ($r2.tg + $r3.tg)/2
$delta = ($bTg - $aTg)/$aTg*100
"=== R13 ABBA 判决 ==="
"A(sw1) mean=$aTg   runs: $($r1.tg) / $($r4.tg)"
"B(sw0) mean=$bTg   runs: $($r2.tg) / $($r3.tg)"
"delta = $([math]::Round($delta,3))%"
$h = @($r1.hash,$r2.hash,$r3.hash,$r4.hash)
"hash: run1=$($h[0].Substring(0,8)) run2=$($h[1].Substring(0,8)) run3=$($h[2].Substring(0,8)) run4=$($h[3].Substring(0,8))"
if(($h[0] -eq $h[1]) -and ($h[1] -eq $h[2]) -and ($h[2] -eq $h[3])){ 'correctness: 4/4 全同（ABBA 期间正确性再确认）' } else { 'correctness: 有 run 分叉（异常！贴日志）' }
if($delta -ge 1.2 -and $delta -le 2.0){ 'R13 PASS：提升超噪声地板且落入预注册带 [+1.53~1.98%] 合格邻域 → 实锤' }
elseif($delta -gt 2.0){ 'R13 超上限：提升超预注册上限 2.0%，存疑（测量条件偏差？）贴全数据' }
elseif($delta -ge 0){ "R13 不显著：$([math]::Round($delta,3))% < 噪声地板 1.2%（如实记录：未证实提升，亦未证伪）" }
else { "R13 亏差：$([math]::Round($delta,3))%（如实记录；嫌疑=fixup 发射频率/capture host 开销 → R14 复盘议题）" }
'R13-DONE'
