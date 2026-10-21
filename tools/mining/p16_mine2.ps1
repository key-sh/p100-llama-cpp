$ErrorActionPreference="Continue"
"=== P16-0b MINE2 START {0} ===" -f (Get-Date -Format "HH:mm:ss")
$lines=[IO.File]::ReadAllLines("D:\temp\traceG_cuda_gpu_trace.csv")
$rxN=[regex]::new("""([^""]+)""$")
$rxD=[regex]::new("^[^,]*,\s*""?(\d+(?:\.\d+)?)")
$rxS=[regex]::new("^([^,]+),")
$agg=@{}; $memC=0; $memT=0.0; $skC=0; $skS=@()
$arT=@(); $flT=@()
for($i=1;$i -lt $lines.Count;$i++){
  $L=$lines[$i]
  $mN=$rxN.Match($L)
  if(-not $mN.Success){ $skC++; if($skS.Count -lt 4){ $skS+=$L }; continue }
  $name=$mN.Groups[1].Value
  $dur=0.0
  $mD=$rxD.Match($L)
  if($mD.Success){ [void][double]::TryParse($mD.Groups[1].Value,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$dur) }
  if($name.StartsWith("[CUDA")){ $memC++; $memT+=$dur; continue }
  if($agg.ContainsKey($name)){ $agg[$name][0]++; $agg[$name][1]+=$dur } else { $agg[$name]=[object[]]@(1,$dur) }
  $mS=$rxS.Match($L); $st=0.0
  if($mS.Success){ [void][double]::TryParse($mS.Groups[1].Value,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$st) }
  if($name.Contains("ar_kernel")){ $arT+=$st }
  if($name.Contains("flash_attn_tile")){ $flT+=$st }
}
$totalK=0.0; foreach($v in $agg.Values){ $totalK+=$v[1] }
"kern_ms={0:N1}  memop_rows={1} memop_ms={2:N1}  skipped={3}" -f ($totalK/1e6),$memC,($memT/1e6),$skC
"skipped_samples:"
$skS
$arS=$arT | Sort-Object
$arB=@(0,0,0,0,0,0); $arD=@()
$prev=0.0
foreach($s in $arS){ if($prev -gt 0){ $arD+=($s-$prev) }; $prev=$s }
"ar_gaps_total={0}" -f $arD.Count
$big=@($arD | Where-Object { $_ -gt 3000000 })
"ar_step_boundaries(gap>3ms)={0}" -f $big.Count
"ar_largest12_gaps_us:"
($arD | Sort-Object -Descending | Select-Object -First 12) | ForEach-Object { "{0:N0}" -f ($_/1e3) }
$flS=$flT | Sort-Object
$flD=@(); $prev=0.0
foreach($s in $flS){ if($prev -gt 0){ $flD+=($s-$prev) }; $prev=$s }
$bigF=@($flD | Where-Object { $_ -gt 3000000 })
"flash_step_boundaries(gap>3ms)={0}" -f $bigF.Count
"== TOP 12 non-AR kernels =="
$agg.GetEnumerator() | Where-Object { -not $_.Key.Contains("ar_kernel") } | Sort-Object { -$_.Value[1] } | Select-Object -First 12 | ForEach-Object { "{0,9}x {1,12:N1} ms  {2}" -f $_.Value[0],($_.Value[1]/1e6),$_.Name.Substring(0,[math]::Min(110,$_.Name.Length)) }
"=== P16-0b MINE2 DONE {0} ===" -f (Get-Date -Format "HH:mm:ss")