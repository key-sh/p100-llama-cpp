$ErrorActionPreference='Stop'
$HDR = @{ Authorization = 'Bearer sk-av3IfMH0FtRoc8rDjYdkA4xJVXKnB5wsUTeLbGWZ' }
$REQ = '{"messages":[{"role":"system","content":"你是一位中文文学创作者。"},{"role":"user","content":"以旧书摊的黄昏为题写一段散文，约两百字。"}],"temperature":0.8,"top_p":0.95,"top_k":40,"min_p":0.05,"seed":42,"max_tokens":256,"stream":false,"cache_prompt":false}'
function Invoke-Probe([int]$sw){
  cmd /c "taskkill /IM llama-server.exe /F >nul 2>&1"; cmd /c "ping -n 15 127.0.0.1 >nul"
  $srv = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','D:\temp\p16_sw.bat',"$sw" -RedirectStandardOutput "D:\temp\p16probe_sw$sw.log" -RedirectStandardError "D:\temp\p16probe_sw$sw.err.log" -PassThru
  try {
    $ok=$false
    foreach($i in 1..1500){
      try { $r=Invoke-WebRequest 'http://127.0.0.1:8080/health' -Headers $HDR -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200){$ok=$true;break} } catch {}
      Start-Sleep -Seconds 1
    }
    if(-not $ok){ throw "sw=$sw health 超时，看 D:\temp\p16probe_sw$sw.log" }
    $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/chat/completions' -Method Post -Headers $HDR -Body ([Text.Encoding]::UTF8.GetBytes($REQ)) -ContentType 'application/json; charset=utf-8' -TimeoutSec 600
    $c = $resp.choices[0].message.content
    if ([string]::IsNullOrWhiteSpace($c)) { $c = $resp.choices[0].message.reasoning_content }
    if ([string]::IsNullOrWhiteSpace($c)) { throw "sw=$sw 内容空" }
    Write-Host ("sw={0} tokens={1} tg={2}" -f $sw,$resp.timings.predicted_n,[math]::Round($resp.timings.predicted_per_second,2))
  } finally {
    cmd /c "taskkill /IM llama-server.exe /F >nul 2>&1"
    if($srv -and -not $srv.HasExited){ Stop-Process -Id $srv.Id -Force }
    cmd /c "ping -n 15 127.0.0.1 >nul"
  }
}
Invoke-Probe 0
Invoke-Probe 1
foreach($sw in 0,1){
  "===== sw=$sw probe log lines ====="
  foreach($lg in @("D:\temp\p16probe_sw$sw.log","D:\temp\p16probe_sw$sw.err.log")){
    if(Test-Path $lg){
      $m=@(Select-String -Path $lg -Pattern 'GP100-P16 probe')
      "{0}: {1} lines" -f $lg,$m.Count
      $m | Select-Object -First 24 | ForEach-Object { $_.Line }
    }
  }
}
'PROBE-RUN-DONE'
