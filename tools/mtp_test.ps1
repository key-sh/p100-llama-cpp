param(
  [string]$Tag  = "run",
  [int]$NPred   = 256,
  [string]$Mode = "summarise",
  [string]$PromptFile = "",
  [string]$Url  = "http://127.0.0.1:8080"
)
$prompt = switch ($Mode) {
  "creative" { "Write the opening of a novel from this outline, under 600 words, cold and terse style: a boy sneaks back into his ancestral home on a stormy night and finds a slightly warm bronze door behind the cellar wall." }
  "file"     { [System.IO.File]::ReadAllText($PromptFile, [System.Text.Encoding]::UTF8) }
  default    { "Summarize the major dynasties and turning points of Chinese history in about 1000 words." }
}
$body = @{
  messages   = @(@{ role = "user"; content = $prompt })
  max_tokens = $NPred
  stream     = $false
} | ConvertTo-Json -Depth 6
$b = [System.Text.Encoding]::UTF8.GetBytes($body)
try {
  $r = Invoke-RestMethod -Uri "$Url/v1/chat/completions" -Method Post -Body $b -ContentType "application/json; charset=utf-8" -TimeoutSec 900
} catch {
  Write-Output "[$Tag] REQUEST FAILED: $($_.Exception.Message)"; exit 1
}
$t = $r.timings
if ($null -eq $t) {
  Write-Output "[$Tag] NO timings FIELD - dumping keys:"; $r.PSObject.Properties.Name; exit 1
}
"[{0}] prompt_n={1}  pp={2:F1} t/s  pred_n={3}  tg={4:F2} t/s   (prompt_ms={5}  pred_ms={6})" -f `
  $Tag, $t.prompt_n, $t.prompt_per_second, $t.predicted_n, $t.predicted_per_second, $t.prompt_ms, $t.predicted_ms
