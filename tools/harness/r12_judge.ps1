$ErrorActionPreference='Continue'
function Get-KLD([string]$p1,[string]$p0){
  try{
    $a=(Get-Content $p1 -Raw|ConvertFrom-Json); $b=(Get-Content $p0 -Raw|ConvertFrom-Json)
    $a1=$a.content; if(-not $a1){$a1=$a}
    $b1=$b.content; if(-not $b1){$b1=$b}
    if(-not $a1 -or -not $b1){ return 'n/a' }
    $n=[Math]::Min($a1.Count,$b1.Count); $sum=0.0; $cnt=0
    for($i=0;$i -lt $n;$i++){
      $ta=@{}; foreach($e in $a1[$i].top_logprobs){ $ta[[string]$e.token]=[double]$e.logprob }
      $tb=@{}; foreach($e in $b1[$i].top_logprobs){ $tb[[string]$e.token]=[double]$e.logprob }
      $u=@($ta.Keys); foreach($k in @($tb.Keys)){ if(-not $ta.ContainsKey($k)){ $u+=$k } }
      $lp=@(); $lq=@()
      foreach($k in $u){
        $lp += $(if($ta.ContainsKey($k)){$ta[$k]}else{-20.0})
        $lq += $(if($tb.ContainsKey($k)){$tb[$k]}else{-20.0})
      }
      $mp=($lp|Measure-Object -Maximum).Maximum; $mq=($lq|Measure-Object -Maximum).Maximum
      $sp=0.0; foreach($v in $lp){$sp+=[Math]::Exp($v-$mp)}; $lpse=$mp+[Math]::Log($sp)
      $sq=0.0; foreach($v in $lq){$sq+=[Math]::Exp($v-$mq)}; $lqse=$mq+[Math]::Log($sq)
      $kl=0.0
      for($j=0;$j -lt $u.Count;$j++){
        $p=[Math]::Exp($lp[$j]-$lpse)
        $kl+=$p*(($lp[$j]-$lpse)-($lq[$j]-$lqse))
      }
      $sum+=$kl; $cnt++
    }
    if($cnt -eq 0){ return 'n/a' } else { return [math]::Round($sum/$cnt,10) }
  } catch { return 'err' }
}
$IDS=@('G1','G2','G3','G4'); $pass=$true
foreach($id in $IDS){
  $t1=(Get-FileHash "D:\temp\r12_${id}_sw1_content.txt").Hash
  $t0=(Get-FileHash "D:\temp\r12_${id}_sw0_content.txt").Hash
  $txtOk=($t1 -eq $t0); if(-not $txtOk){$pass=$false}
  $lp1="D:\temp\r12_${id}_sw1_lp.json"; $lp0="D:\temp\r12_${id}_sw0_lp.json"
  $lpOk='-'; $kld='-'
  if((Test-Path $lp1) -and (Test-Path $lp0)){
    $lpOk=((Get-FileHash $lp1).Hash -eq (Get-FileHash $lp0).Hash)
    if($lpOk){ $kld=0 } else { $kld=Get-KLD $lp1 $lp0 }
  }
  "{0}: text={1}  lp={2}  KLD={3}" -f $id,$(if($txtOk){'MATCH'}else{'DIFF'}),$lpOk,$kld
}
if($pass){'R12 PASS：golden 4/4 文本逐位全同'}else{'R12 FAIL：贴对应 DIFF 的两 content 首分歧处'}
