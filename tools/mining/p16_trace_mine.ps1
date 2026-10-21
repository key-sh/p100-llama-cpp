$ErrorActionPreference="Continue"
"=== P16-0 TRACEG MINE START {0} ===" -f (Get-Date -Format "HH:mm:ss")
$path="D:\temp\traceG_cuda_gpu_trace.csv"
$lines=[IO.File]::ReadAllLines($path)
"total_lines={0}" -f $lines.Count
"header={0}" -f $lines[0]
$agg=@{}
$rxN=[regex]::new('"([^"]+)"$')
$rxD=[regex]::new('^[^,]*,\s*"?(\d+(?:\.\d+)?)')
$kernels=0; $memops=0; $skipped=0
for($i=1;$i -lt $lines.Count;$i++){
  $L=$lines[$i]
  if($L.Length -lt 10){ $skipped++; continue }
  $mN=$rxN.Match($L)
  if(-not $mN.Success){ $skipped++; continue }
  $name=$mN.Groups[1].Value
  $mD=$rxD.Match($L)
  $dur=0.0
  if($mD.Success){ [void][double]::TryParse($mD.Groups[1].Value,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$dur) }
  if($name.StartsWith("[CUDA")){ $memops++ } else { $kernels++ }
  if($agg.ContainsKey($name)){ $agg[$name][0]++; $agg[$name][1]+=$dur } else { $agg[$name]=[object[]]@(1,$dur) }
  if(($i % 50000) -eq 0){ Write-Host ("...progress {0}/{1}" -f $i,$lines.Count) }
}
$totalAll=0.0
foreach($v in $agg.Values){ $totalAll+=$v[1] }
"kernel_rows={0} memop_rows={1} skipped={2} distinct_names={3} total_gpu_ms={4:N1}" -f $kernels,$memops,$skipped,$agg.Count,($totalAll/1e6)
"== TOP 30 BY TOTAL GPU TIME =="
$agg.GetEnumerator() | Sort-Object { -$_.Value[1] } | Select-Object -First 30 | ForEach-Object { "{0,9}x {1,12:N1} ms {2,9:N2} us/ea  {3}" -f $_.Value[0],($_.Value[1]/1e6),($_.Value[1]/1e3/$_.Value[0]),$_.Name }
"== P16 TARGET FAMILIES (name contains, buckets may overlap) =="
$fams=@("rope","flash","fattn","ar_kernel","ar_add","mmvq","mmvf","mmq","norm","concat","cpy","ssm","scan","gated","wkv","delta","soft","acc_","add","scale","argsort","topk","glu","silu")
foreach($f in $fams){
  $c=0; $d=0.0
  foreach($e in $agg.GetEnumerator()){ if($e.Key.ToLower().Contains($f)){ $c+=$e.Value[0]; $d+=$e.Value[1] } }
  if($c -gt 0){ "{0,-10} {1,9}x {2,12:N1} ms {3,6:N1} pct" -f $f,$c,($d/1e6),(100*$d/[math]::Max($totalAll,1)) }
}
"=== P16-0 TRACEG MINE DONE {0} ===" -f (Get-Date -Format "HH:mm:ss")