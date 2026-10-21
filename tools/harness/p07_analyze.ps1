$ErrorActionPreference='Continue'
"=== P07 ANALYZE START {0} ===" -f (Get-Date -Format 'HH:mm:ss')
$tg=[IO.File]::ReadAllLines('D:\temp\p07_soak_tg.csv',[Text.Encoding]::UTF8) | Where-Object { $_ -match '\S' }
"tg_total_lines=$($tg.Count)"
$data=@($tg | Select-Object -Skip 1)
$err=@($data | Where-Object { $_.Contains(',ERR,') })
$ok=@($data | Where-Object { -not $_.Contains(',ERR,') })
"rows=$($data.Count) ok=$($ok.Count) err=$($err.Count)"
"first3:"; $data | Select-Object -First 3
if($data.Count -ge 5){ $m=[int]($data.Count/2); "mid3:"; $data[($m-1)..($m+1)] }
"last3:"; $data | Select-Object -Last 3
if($err.Count -gt 0){ "err_first3:"; $err | Select-Object -First 3 }
if($ok.Count -ge 13){
  $pn=@(); $tgv=@()
  foreach($r in $ok){ $p=$r.Split(','); if($p.Count -ge 4){ $pn+=[int]$p[2]; $tgv+=[double]$p[3] } }
  $n=$pn.Count
  $sp=$pn | Sort-Object; "pn min/med/max: $($sp[0]) / $($sp[[int]($n/2)]) / $($sp[-1])"
  $st=$tgv | Sort-Object; "tg min/med/max: {0:N2} / {1:N2} / {2:N2}" -f $st[0],$st[[int]($n/2)],$st[-1]
  $ea=($tgv[3..12] | Measure-Object -Average).Average
  $la=($tgv | Select-Object -Last 10 | Measure-Object -Average).Average
  "early(req4-13)={0:N2}  late(last10)={1:N2}  slope_ratio={2:N4}" -f $ea,$la,($la/$ea)
  try{
    $ci=[Globalization.CultureInfo]::InvariantCulture
    $t0=[datetime]::ParseExact($data[0].Split(',')[1],'HH:mm:ss',$ci)
    $t1=[datetime]::ParseExact($data[-1].Split(',')[1],'HH:mm:ss',$ci)
    $t2=[datetime]::ParseExact($data[1].Split(',')[1],'HH:mm:ss',$ci)
    "span_min={0:N1}  avg_sec_per_req={1:N2}  first_req_sec={2:N1}" -f ($t1-$t0).TotalMinutes,(($t1-$t0).TotalSeconds/($data.Count-1)),($t2-$t0).TotalSeconds
    $ts0=$data[0].Split(',')[1]; $ts1=$data[-1].Split(',')[1]
    $smi=[IO.File]::ReadAllLines('D:\temp\p07_smi.csv',[Text.Encoding]::UTF8)
    "smi_total=$($smi.Count)"
    $inW=@($smi | Where-Object { if($_ -match '(\d\d:\d\d:\d\d)'){ $mm=$Matches[1]; ($mm -ge $ts0) -and ($mm -le $ts1) } else { $false } })
    "soak_window_lines=$($inW.Count)"
    if($inW.Count -ge 1000){
      "win_head:"; $inW | Select-Object -First 4
      "win_stride60s:"
      $steps=[int][math]::Floor(($inW.Count-1)/240)
      0..$steps | ForEach-Object { $inW[$_*240] }
      "win_tail:"; $inW | Select-Object -Last 4
    } else {
      "WINDOW TOO SMALL (midnight cross?) - raw strides every ~10min:"
      $steps2=[int][math]::Floor(($smi.Count-1)/2400)
      0..$steps2 | ForEach-Object { $smi[$_*2400] }
    }
    "smi_now_tail:"; $smi | Select-Object -Last 4
  }catch{ "smi_analysis_error: $($_.Exception.Message)" }
}
"srv_log_tail:"
[IO.File]::ReadAllLines('D:\temp\srv_p07_soak.log',[Text.Encoding]::UTF8) | Select-Object -Last 10
"=== P07 ANALYZE DONE {0} ===" -f (Get-Date -Format 'HH:mm:ss')