$ErrorActionPreference="Continue"
"=== P07 RE-ANALYZE START {0} ===" -f (Get-Date -Format "HH:mm:ss")
$tg=[IO.File]::ReadAllLines("D:\temp\p07_soak_tg.csv",[Text.Encoding]::UTF8) | Select-Object -Skip 1
$ok=@($tg | Where-Object { -not $_.Contains(",ERR,") })
$real=@(); $ghost=0; $badparse=0
foreach($r in $ok){
  $p=$r.Split(",")
  if($p.Count -ge 4){
    $v=[double]0
    if([double]::TryParse($p[3],[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$v)){
      if(($v -gt 5) -and ($v -lt 200)){ $real+=[pscustomobject]@{idx=$p[0];t=$p[1];pn=[int]$p[2];tg=$v} } else { $ghost++ }
    } else { $badparse++ }
  }
}
"ok_rows={0} valid_rows={1} ghost={2} badparse={3}" -f $ok.Count,$real.Count,$ghost,$badparse
$hist=@{}
foreach($x in @($real | ForEach-Object { $_.pn })){
  $b = if($x -le 5){"a:1-5"} elseif($x -le 50){"b:6-50"} elseif($x -le 200){"c:51-200"} elseif($x -le 400){"d:201-400"} else {"e:401+"}
  if($hist.ContainsKey($b)){ $hist[$b]++ } else { $hist[$b]=1 }
}
"pn_histogram:"
$hist.GetEnumerator() | Sort-Object Name | ForEach-Object { "  {0} = {1}" -f $_.Name,$_.Value }
$tgv=@($real | ForEach-Object { $_.tg })
if($tgv.Count -ge 20){
  $ea=($tgv[0..9] | Measure-Object -Average).Average
  $la=($tgv[($tgv.Count-10)..($tgv.Count-1)] | Measure-Object -Average).Average
  "valid first10_mean={0:N3}  last10_mean={1:N3}  slope_ratio={2:N4}" -f $ea,$la,($la/$ea)
  $st=$tgv | Sort-Object
  "valid tg min/med/max: {0:N2} / {1:N2} / {2:N2}" -f $st[0],$st[[int]($st.Count/2)],$st[-1]
}
"valid_first_row: {0}" -f $real[0]
"valid_last_row:  {0}" -f $real[-1]
"=== P07 RE-ANALYZE DONE {0} ===" -f (Get-Date -Format "HH:mm:ss")