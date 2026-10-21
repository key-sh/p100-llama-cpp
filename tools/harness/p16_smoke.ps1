$ErrorActionPreference='Stop'
$HDR = @{ Authorization = 'Bearer sk-av3IfMH0FtRoc8rDjYdkA4xJVXKnB5wsUTeLbGWZ' }
$REQ = '{"messages":[{"role":"user","content":"以旧书摊的黄昏 为题写一段散文，约两百字。"}],"temperature":0.8,"top_p":0.95,"top_k":40,"min_p":0.05,"seed":42,"max_tokens":256,"stream":false,"cache_prompt":false}'
cmd /c "taskkill /IM llama-server.exe /F >nul 2>&1"; cmd /c "ping -n 15 127.0.0.1 >nul"
$i=Get-Item 'D:\p100-llama-cpp\llama.cpp\build\bin\Release\ggml-cuda.dll'; "dll: {0}  {1}B" -f $i.LastWriteTime,$i.Length
$srv = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','D:\temp\p16_launch.bat' -RedirectStandardOutput 'D:\temp\p16smoke.log' -RedirectStandardError 'D:\temp\p16smoke.err.log' -PassThru
try {
  $ok=$false
  foreach($k in 1..1500){ try { $r=Invoke-WebRequest 'http://127.0.0.1:8080/health' -Headers $HDR -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200){$ok=$true;break} } catch {}; Start-Sleep -Seconds 1 }
  if(-not $ok){ throw 'health timeout' }
  $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/chat/completions' -Method Post -Headers $HDR -Body ([Text.Encoding]::UTF8.GetBytes($REQ)) -ContentType 'application/json; charset=utf-8' -TimeoutSec 600
  $len = 0; if($resp.choices[0].message.content){ $len = $resp.choices[0].message.content.Length }
  $line = "smoke OK: tokens={0} tg={1} finish={2} content_len={3}" -f $resp.timings.predicted_n,[math]::Round($resp.timings.predicted_per_second,2),$resp.choices[0].finish_reason,$len
  $line; $line | Set-Content D:\temp\p16_smoke_result.txt -Encoding ASCII
} finally {
  cmd /c "taskkill /IM llama-server.exe /F >nul 2>&1"
  if($srv -and -not $srv.HasExited){ Stop-Process -Id $srv.Id -Force }
  cmd /c "ping -n 15 127.0.0.1 >nul"
}
