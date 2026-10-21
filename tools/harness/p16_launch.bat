rem 每卡占用显存13-15G，输出速度pp 171-296t/s，tg 33-34t/s
rem 【p100专用，Qwen3.8-27B-UD-Q8_K_XL.gguf · 262144 ctx · tensor分卡 · MTP关闭 · 文学创作档】
set CUDA_VISIBLE_DEVICES=0,1,2,3
set OMP_NUM_THREADS=30
set OMP_WAIT_POLICY=ACTIVE
set GGML_CUDA_GRAPH_FORCE=1
set GGML_CUDA_ALLREDUCE=
set GGML_CUDA_P2P=
set GGML_NUMA=
set GGML_CUDA_FORCE_CUBLAS=
cd /d D:\p100-llama-cpp\llama.cpp\build\bin\Release
llama-server.exe ^
  --model G:\AiModels\001\002\Qwen3.8-27B-UD-Q8_K_XL.gguf ^
  --ctx-size 262144 ^
  --n-gpu-layers 999 ^
  --split-mode tensor ^
  --tensor-split 16,16,16,16 ^
  --batch-size 8192 ^
  --ubatch-size 4096 ^
  --threads 20 ^
  --parallel 2 ^
  --host 127.0.0.1 ^
  --port 8080 ^
  --temp 0.8 ^
  --top-p 0.95 ^
  --top-k 40 ^
  --min-p 0.05 ^
  --repeat-penalty 1.05 ^
  --repeat-last-n 256 ^
  --dry-multiplier 0.8 ^
  --dry-base 1.75 ^
  --dry-allowed-length 2 ^
  --presence-penalty 0.3 ^
  --fit off ^
  -fa on ^
  --cache-type-k f16 ^
  --cache-type-v f16 ^
  --api-key sk-av3IfMH0FtRoc8rDjYdkA4xJVXKnB5wsUTeLbGWZ ^
  --jinja ^
  --load-mode none
