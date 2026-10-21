$ErrorActionPreference='Stop'
$HDR = @{ Authorization = 'Bearer sk-av3IfMH0FtRoc8rDjYdkA4xJVXKnB5wsUTeLbGWZ' }
$GOLDENS = @(
  @{ id='G1'; n=256; sys='你是一位中文文学创作者。'; usr='以旧书摊的黄昏为题写一段散文，约两百字。' },
  @{ id='G2'; n=512; sys='你是一位中文文学创作者。'; usr='以深海灯塔为题写一篇微型小说，约五百字，结尾要有反转。' },
  @{ id='G3'; n=256; sys='你是一位严谨的数学助手。'; usr='一个三位数，各位数字之和为 12；交换它的百位与个位后，新数比原数小 198。求原数并给出完整推理。' },
  @{ id='G4'; n=256; sys='你是一位翻译家。'; usr='把这句中文翻译成英文：江南的雨落在青石板上，像时间在低声背诵一封旧信。' }
)
function Run-Goldens([int]$sw){
  cmd /c "taskkill /IM llama-server.exe /F >nul 2>&1"; cmd /c "ping -n 7 127.0.0.1 >nul"
  $srv = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','D:\temp\p16_sw.bat',"$sw" -RedirectStandardOutput "D:\temp\p16srv_gold_sw$sw.log" -RedirectStandardError "D:\temp\p16srv_gold_sw$sw.err.log" -PassThru
  try {
    $ok=$false
    foreach($i in 1..1500){
      try { $r=Invoke-WebRequest 'http://127.0.0.1:8080/health' -Headers $HDR -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200){$ok=$true;break} } catch {}
      Start-Sleep -Seconds 1
    }
    if(-not $ok){ throw "sw=$sw health 超时，看 D:\temp\p16srv_gold_sw$sw.log" }
    foreach($g in $GOLDENS){
      $req = [ordered]@{
        messages=@(@{role='system';content=$g.sys},@{role='user';content=$g.usr})
        temperature=0.8; top_p=0.95; top_k=40; min_p=0.05
        seed=42; max_tokens=$g.n; stream=$false; cache_prompt=$false
      }
      $lpMode=$true
      $req['logprobs']=$true; $req['top_logprobs']=10
      $body = $req | ConvertTo-Json -Depth 8
      try {
        $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/chat/completions' -Method Post -Headers $HDR -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json; charset=utf-8' -TimeoutSec 900
        if(-not $resp.choices[0].logprobs){ $lpMode=$false }
      } catch {
        $req.Remove('logprobs'); $req.Remove('top_logprobs')
        $body = $req | ConvertTo-Json -Depth 8
        $lpMode=$false
        $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/chat/completions' -Method Post -Headers $HDR -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json; charset=utf-8' -TimeoutSec 900
      }
      $c = $resp.choices[0].message.content
      if ([string]::IsNullOrWhiteSpace($c)) { $c = $resp.choices[0].message.reasoning_content }
      if ([string]::IsNullOrWhiteSpace($c)) { throw "$($g.id) sw=$sw 内容空，看 raw json" }
      if ($resp.timings.predicted_n -lt $g.n) { throw "$($g.id) sw=$sw tokens=$($resp.timings.predicted_n)<$($g.n)" }
      ($resp | ConvertTo-Json -Depth 12) | Set-Content "D:\temp\r12_$($g.id)_sw${sw}_raw.json" -Encoding UTF8
      [IO.File]::WriteAllText("D:\temp\r12_$($g.id)_sw${sw}_content.txt", $c, (New-Object Text.UTF8Encoding($false)))
      if($lpMode){ $resp.choices[0].logprobs | ConvertTo-Json -Depth 12 | Set-Content "D:\temp\r12_$($g.id)_sw${sw}_lp.json" -Encoding UTF8 }
      "{0} sw={1}  chars={2}  tokens={3}  tg={4}  lp={5}" -f $g.id,$sw,$c.Length,$resp.timings.predicted_n,[math]::Round($resp.timings.predicted_per_second,2),$lpMode
    }
  } finally {
    cmd /c "taskkill /IM llama-server.exe /F >nul 2>&1"
    if($srv -and -not $srv.HasExited){ Stop-Process -Id $srv.Id -Force }
    cmd /c "ping -n 7 127.0.0.1 >nul"
  }
}
Run-Goldens 1; Run-Goldens 0
'R12-COLLECT-DONE'
