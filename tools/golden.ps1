param(
  [string]$Tag  = "g",
  [int]$NPred   = 256,
  [string]$Url  = "http://127.0.0.1:8080"
)
$prompt = "Summarize the major dynasties and turning points of Chinese history in about 1000 words."
$body = @{
  messages              = @(@{ role = "user"; content = $prompt })
  max_tokens            = $NPred
  temperature           = 0
  stream                = $false
  chat_template_kwargs  = @{ enable_thinking = $false }
} | ConvertTo-Json -Depth 6
$b = [System.Text.Encoding]::UTF8.GetBytes($body)
try {
  $r = Invoke-RestMethod -Uri "$Url/v1/chat/completions" -Method Post -Body $b -ContentType "application/json; charset=utf-8" -TimeoutSec 900
} catch {
  Write-Output "[$Tag] REQUEST FAILED: $($_.Exception.Message)"; exit 1
}
$t = $r.timings
$c = @($r.choices)[0].message
$txt = [string]$c.content
if ($c.reasoning_content) { $txt = $txt + "|" + [string]$c.reasoning_content }
if ([string]::IsNullOrEmpty($txt)) { Write-Output "[$Tag] EMPTY CONTENT (check response shape)"; exit 1 }
$f = "D:\temp\golden_$Tag.txt"
[System.IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UTF8Encoding($false)))
$md5 = (Get-FileHash -Path $f -Algorithm MD5).Hash.ToLower()
"[{0}] md5={1}  prompt_n={2}  pred_n={3}  tg={4:F2}  file={5}" -f $Tag, $md5, $t.prompt_n, $t.predicted_n, $t.predicted_per_second, $f
