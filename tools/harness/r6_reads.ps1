$ErrorActionPreference="Continue"
"=== R6 READS START {0} ===" -f (Get-Date -Format "HH:mm:ss")
$L=[IO.File]::ReadAllLines("D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\ggml-cuda.cu",[Text.Encoding]::UTF8)
"== L5a: GGML_CUDA_ALLREDUCE context (1215-1260) =="
$L[1215..1260]
"== L5b: GGML_CUDA_P2P contexts (385-410, 600-625) =="
$L[385..410]
$L[600..625]
"== L5c: GGML_CUDA_GRAPH_OPT context (4808-4830) =="
$L[4808..4830]
"== L6a: should_use_mmvq body =="
$L | Select-String -SimpleMatch "ggml_cuda_should_use_mmvq" -Context 0,30 | Select-Object -First 1
"== L6b: should_use_mmq body =="
$L | Select-String -SimpleMatch "static bool ggml_cuda_should_use_mmq" -Context 0,35 | Select-Object -First 1
"== L7: gp100_mmvq_b32 kernel body head (975-1060) =="
$M=[IO.File]::ReadAllLines("D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\mmvq-gp100.cu",[Text.Encoding]::UTF8)
$M[975..1060]
"=== R6 READS DONE {0} ===" -f (Get-Date -Format "HH:mm:ss")