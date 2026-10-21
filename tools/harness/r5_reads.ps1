$ErrorActionPreference="Continue"
"=== R5 READS START {0} ===" -f (Get-Date -Format "HH:mm:ss")

"== L0: traceG device histogram (capture regime check) =="
$txt=[IO.File]::ReadAllText("D:\temp\traceG_cuda_gpu_trace.csv")
$m=[regex]::Matches($txt,"P100-PCIE-16GB \((\d)\)")
$dev=@{}
foreach($x in $m){ $k=$x.Groups[1].Value; if($dev.ContainsKey($k)){$dev[$k]++}else{$dev[$k]=1} }
$dev.GetEnumerator() | Sort-Object Name | ForEach-Object { "dev{0}: {1} rows" -f $_.Name,$_.Value }
"total_dev_tagged_rows={0}" -f $m.Count

"== L1: srv_p2p1.log full dump (45 lines) =="
[IO.File]::ReadAllLines("D:\temp\srv_p2p1.log",[Text.Encoding]::UTF8)

"== L2a: AR env knobs (ar_env_u64 call sites) =="
$ar=[IO.File]::ReadAllLines("D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\allreduce.cu",[Text.Encoding]::UTF8)
$ar | Select-String -SimpleMatch "ar_env_u64(" | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.TrimEnd() }

"== L2b: getenv inventory across ggml-cuda (cap 40) =="
Get-ChildItem "D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda" -Filter *.cu* | ForEach-Object { $p=$_.FullName; [IO.File]::ReadAllLines($p,[Text.Encoding]::UTF8) | Select-String -SimpleMatch "getenv(" | ForEach-Object { "{0}:{1}: {2}" -f (Split-Path $p -Leaf),$_.LineNumber,$_.Line.TrimEnd() } } | Select-Object -First 40

"== L3: mul_mat dispatch vec-vs-GEMM (ggml-cuda.cu 1818-1935) =="
$L=[IO.File]::ReadAllLines("D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\ggml-cuda.cu",[Text.Encoding]::UTF8)
$L[1818..1935]

"== L4: gp100_mmvq_b32 template line numbers =="
$M=[IO.File]::ReadAllLines("D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\mmvq-gp100.cu",[Text.Encoding]::UTF8)
$M | Select-String -SimpleMatch "gp100_mmvq_b32" | Select-Object -First 10 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.TrimEnd() }

"=== R5 READS DONE {0} ===" -f (Get-Date -Format "HH:mm:ss")