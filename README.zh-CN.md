[English](README.md) | 简体中文

# 在 Tesla P100（GP100，sm_60）上加速 llama.cpp 解码

## 快速开始

本仓库自带一个已打好 P100 补丁系列、开箱即建的 llama.cpp：

```sh
git clone https://github.com/key-sh/p100-llama-cpp && cd p100-llama-cpp
git checkout p100-gp100-fp32

./build.sh   # 需要 CUDA 12.x + cmake；二进制位于 llama.cpp/build/bin/

# 单张 P100
llama.cpp/build/bin/llama-server -m model.gguf -ngl 99

# 两张 P100：张量拆分（tensor split）正是补丁 0003/0004 发力之处
llama.cpp/build/bin/llama-server -m model.gguf -ngl 99 -sm tensor
```

`llama.cpp/` 目录就是上游 **`b10660`** 加 `patches/0001`-`0012`，别无他物；`tools/verify-source.sh` 可以从上游重新推导出该目录并 diff 来证明这一点。它就是产出下列数字的机器上实际运行的源码。

**本分支（`p100-gp100-fp32`，key-sh）与上述描述不同**：其源码树为 `cde4ecf`（上游 `b10660` + 补丁 `0001`-`0009`），以源码编辑方式重新应用了补丁 `0010`，另含下文专节《本分支（key-sh）：FA-GEMM 默认 fp32》记载的加固改动——面向 GLU 模型的 `mmvq-gp100` 守卫、FA-GEMM 的 PV 调用移除 `CUBLAS_GEMM_ALGO4`、以及 fp32 默认；另含下文专节《本分支（key-sh）：`GGML_CUDA_GRAPH_FORCE`——Volta 前显卡的 CUDA graph 解锁》记载的改动——图解锁，以及默认关闭的 AllReduce P2P staging 变体（见下文专节）。
`patches/0010`-`0012` 文件仅作参考保留：`0011`/`0012` 的代码**未**应用在本分支上（纯 GP100 机器根本不会执行到它们所改动的代码路径，且下文验证正是在这棵树上完成的）。经全套验证的二进制为 `ggml-cuda.dll`，SHA256 `d1ace29be270f8e8c810620a73f63615c6c9a651289629ab13dd3cddc1327b9d`——对应上述两项分支新增**之前**的树；两项新增以各自专节记载的逐字节输出门完成验证，而非新的二进制哈希。

你的配置能获得什么，取决于你的环境：

| 你的配置 | 生效改动 | 预期收益 |
|---|---|---|
| 任意 P100（sm_60）+ 量化模型 | `0007` + `0008` | fp16 矩阵-向量路径：**Llama-3.1-8B Q4_K_M tg 39.3 → 79.6，即 2.03 倍**；双卡 qwen3.8-27b tg 25.0 → 33.7，真实提示词下 MTP 26.2 → 40.9 tok/s，且比原版*更*精确——见 [`docs/fp16-mmvq.md`](docs/fp16-mmvq.md) |
| 任意 P100 + 同时跑多路序列（`llama-server --parallel N`，并发 agent） | `0011`（叠加于 `0007`-`0009`） | fp16 与融合路径上的批量解码：**qwen3.8-27b 四个并发 agent 单体 16.0 → 20.3 tok/s（合计 58.7 → 72.9）**，单 agent 不变——见 [`docs/concurrent-decode.md`](docs/concurrent-decode.md)。**本分支仅收录参考、未应用——见上文树状态说明** |
| 任意 Volta 之前的卡 + 长上下文 | `0010`（**代码来自 [Kmic-68 的 fork](https://github.com/Kmic-68/llama.cpp)**） | 面向长 prefill 的 cuBLAS-GEMM flash attention，外加 GQA-6 tile 内核：**qwen3.8-27b pp2048 在 32k 深度 285.6 → 352.9（+23.6%）**，困惑度不变——见 [`docs/long-context-attention.md`](docs/long-context-attention.md) |
| 任意 P100 + **本分支** + `-fa on` | key-sh：**FA-GEMM 默认 fp32** | 长提示词不再出现 NaN（fp16 路径在本机/此模型上会毒化——见下方专节）；8k 上下文 prefill 代价约 1.5% |
| 任意 P100 + Qwen3.8 / Qwen3-Next 式 gated delta-net 模型 | `0009`（叠加于 `0007`/`0008`） | 循环状态的零散内核折叠进已有内核：**qwen3.8-27b 实用解码 32.3 → 35.3 tok/s（+9.1%）**，每 token 少 480 次内核启动，输出逐位一致——见 [`docs/delta-net-fusions.md`](docs/delta-net-fusions.md) |
| 单张 P100 + K 量化模型（Q4_K_M 等） | `0001` + `0002` | 解码的大头收益，例如 Llama-3.1-8B tg +33% |
| 任意 P100 | `0005` + 默认 f16 KV cache（**不要**传 `-ctk q8_0`） | prefill 约 +5%；长上下文下 f16 KV 增长到 +24% tg |
| 双 P100 + `-sm tensor` | 以上全部 + `0003` + `0004` | 再加约 +15% prefill、+10% tg |
| 三张及以上 P100 + `-sm tensor` | 以上全部 + `0006` | key-sh 已在四张物理卡上实测：内部 AllReduce 对主机内存回退 **prefill 2.3 倍 / tg +39%**，输出逐字节一致——见下文"三卡及以上" |
| 任意 P100 + **本分支**，任意模型，单卡或多卡 | key-sh：`GGML_CUDA_GRAPH_FORCE=1` | Volta 之下的 CUDA graph 管线解锁：qwen3.8-27B-UD tg128 32.5 → 37.4（+15%），n2048 +17%；MoE qwen3.6-35B-A3B tg 33.6 → 83.8（**2.5 倍**）；真实 server 请求 27B 22.9 → 32.5（+42%）、MoE 23.2 → 61.5（**2.6 倍**）；temp 0 下输出逐字节一致——见下文专节 |
| P40 / GTX 10xx（sm_61） | `0001`、`0005` | 收益小；`0002` 按设计仅限 GP100。`./build.sh` 会探测显卡；传 `CUDA_ARCH="60;61"` 可构建同时服务两种卡的二进制。（`0012` 本分支仅收录参考） |

**三卡及以上。** 上游 llama.cpp 的内部 AllReduce（`ggml/src/ggml-cuda/allreduce.cu`）只支持恰好两个设备；更多时会记录 `internal AllReduce init failed (n_devices != 2?)` 并回退到经主机内存的通用 f32 交换——而这正是 `0003` 要避免的路径。`0006` 把它扩展到 N 个设备。仅做了**正确性测试**：在 2x P100 上用 `GGML_CUDA_DEVICES` 拆成 3、4 个虚拟设备，困惑度与原版回退路径一致（4 设备完全相同，3 设备差 <0.02%），chunked、copy-engine 与混合路径输出一致；双卡输出与 `0005` 逐位一致，tg 不变。虚拟设备共享同一 GPU 与 PCIe 链路，因此原始测量**没有真实 3+ 卡整机的速度数据**——如果你的配置不在下文覆盖范围内，请对比 `-sm tensor` 开/关 `GGML_CUDA_ALLREDUCE=none` 的表现并反馈。`-sm layer` 不使用 AllReduce，任意卡数可用。

**四卡实测补充（key-sh，2026-10）。**上文的邀请已在本机兑现：**4x Tesla P100-PCIE-16GB（物理四卡）**、`-sm tensor`、`--tensor-split 25,25,25,25`、本分支源码树、qwen3.8-27B-UD-Q8_K_XL、8k ctx、`-fa on`、f16 KV、ubatch 1024。真实 7,695-token 请求的 prefill：内部 AllReduce **315.2 tok/s**，`GGML_CUDA_ALLREDUCE=none`（通用 f32 经主机内存回退）**137.3 / 137.7 tok/s**（两轮全新运行）——**2.3 倍**。token 生成（128 token、temp 0）：**27.22 对 19.63 tok/s**——**+39%**。输出校验：两条路径的 128-token temp-0 输出**逐字节一致（MD5 相同）**。附带收获：7,695-token 触发提示词在四卡布局、两条路径下均未毒化——fp32 修复在 4 设备配置上同样成立。方法说明：数字来自 `llama-server` 真实请求，每配置单发（回退路径的 pp 跑了两轮作重复性检查），非 llama-bench 的 r=3 统计——量级可信，精密度有限。结论：在真实四卡整机上，内部 AllReduce 不只是正确，而是在 prefill（2.3 倍）与 decode（+39%）上都决定性地快于主机内存回退——`-sm tensor` 的多卡故事延伸到了两张卡之外。本分支随后新增的 CUDA graph 解锁（见下文《本分支（key-sh）：`GGML_CUDA_GRAPH_FORCE`》）在其上再叠一层：稠密模型 decode 再 +15-17%，MoE 模型 **2.5 倍**，temp 0 下输出逐字节一致。

**不要设置 `GGML_CUDA_P2P`**——在这台双插槽 P100 机器上是 10.7 倍的倒退（见下文）。本 README 所有数字都测自同一台机器（2x P100-PCIE-16GB 分属不同 CPU 插槽，250 W 功耗墙）；你的数字会不同，但机理应当一致。 llama.cpp 采用 MIT 许可，© the ggml authors——见 `llama.cpp/LICENSE`。本 fork 与 llama.cpp 项目无从属关系，亦未获其认可。

---

对 llama.cpp CUDA 后端的两个小补丁，让单张 P100 的 token 生成**快 33%、双卡快 23%**，以及引出它们的测量：

| 模型 | 配置 | 之前 | 之后 | | |
|---|---|---|---|---|---|
| Llama-3.1-8B Q4_K_M | 单卡 | 39.28 tok/s | **52.22** | **+32.9%** | |
| Llama-3.1-8B Q4_K_M | 双卡，`-sm tensor` | 56.80 tok/s | **70.00** | **+23.2%** | |
| Qwen3.8-27B Q4_K_XL | 双卡，`-sm tensor` | 19.40 tok/s | **22.70** | **+17.0%** | |
| 任意 | prompt processing | — | — | 不变 | |

第三个补丁（后加）面向**多 GPU** 而非量化内核，同时推动 prefill：

| 模型 | 配置 | 之前 | 之后 | |
|---|---|---|---|---|
| Qwen3.8-27B Q4_K_XL | 双卡，`-sm tensor`，pp8192 | 323.6 tok/s | **378.7** | **+17.0%** |
| Qwen3.8-27B Q4_K_XL | 双卡，`-sm tensor`，tg128 | 22.3 tok/s | **24.5** | **+9.6%** |
| Qwen3.8-27B Q4_K_XL | 真实 7,655-token 请求 | 326.9 tok/s | **360.0** | **+10.1%** |

第四个补丁让那次多 GPU 交换的两个方向重叠执行：

| 模型 | 配置 | 之前 | 之后 | |
|---|---|---|---|---|
| Qwen3.8-27B Q4_K_XL | 双卡，`-sm tensor`，pp2048 | 401.3 tok/s | **424.6** | **+5.7%** |
| Qwen3.8-27B Q4_K_XL | 真实 7,655-token 请求 | 361.1 tok/s | **379.7** | **+5.1%** |
| Qwen3.8-27B Q4_K_XL | 35 分钟浸泡，1.7k-17k token 提示词 | 334.7 tok/s | **350.4** | **+4.7%** |

第五个补丁向量化了喂给 cuBLAS prefill 路径的 f32↔f16 转换：

| 模型 | 配置 | 之前 | 之后 | |
|---|---|---|---|---|
| Qwen3.8-27B Q4_K_XL | 双卡，`-sm tensor`，pp2048 | 427.0 tok/s | **448.7** | **+5.1%** |
| Qwen3.8-27B Q4_K_XL | 双卡，`-sm tensor`，pp16384 | 384.0 tok/s | **401.4** | **+4.5%** |
| Qwen3.8-27B Q4_K_XL | 真实 7,655-token 请求 | 381.1 tok/s | **398.5** | **+4.6%** |

补丁 `0007` 与 `0008` 彻底替换了 batch-1 的矩阵-向量路径。sm_60 没有 `__dp4a`，原版 llama.cpp 用四次标量乘法模拟每个 int8 点积；而 GP100 拥有全速的 packed fp16 单元。`0007` 把激活值一次性转成 fp16，并把权重直接解包成**次正规（subnormal）** half 位模式——精确，且不需要魔数减法。`0008` 把短矩阵沿 K 的遍历拆分到块的四个 warp 上，使 24 行的矩阵乘不再是一条 160 块的串行链。单卡、同参数、冷机起始、r=3 实测：

| 模型 | 配置 | 原版 `b10660` | `0001`-`0005` | `+0007`/`0008` | |
|---|---|---|---|---|---|
| Llama-3.1-8B Q4_K_M | 单卡，tg128 | 39.26 tok/s | 52.11 | **79.57** | **2.03x** |
| Llama-3.1-8B Q4_K_M | 单卡，pp512 | 692.9 tok/s | 720.6 | 720.0 | 不变 |

8B 比 Qwen3.8-27B 涨得多（+34%），在预估自家模型前值得知道原因：Q4_K_M 以 **Q4_K 为主——这批内核里它最快**（就地实测 517 GB/s，是该访问形状可达值的 95%）；Qwen3.8-27B 则有 45% 是 427 GB/s 的 Q5_K、18% 是 346 GB/s 的 IQ4_XS，还要支付单卡模型没有的跨卡 AllReduce。**你的量化配比越接近纯 Q4_K，收益越大。**而且它比原版*更*精确——被替换的原路径会把激活量化到 8 位。

补丁 `0009` 攻坚的是矩阵-向量路径变快之后剩下的部分：matmul *之间*的那些内核。Qwen3.8-27B 的 48 层 gated delta-net 中，解码的每一步、每一层都要跑十个小内核，只为把循环状态从缓存拷出、重建 conv 窗口、归一化 q/k 并施加两个激活——每个 2-9 μs，在 GP100 上主要是启动延迟。`0009` 把它们折叠进本来就要读这些数据的内核。每个融合结果都**逐位一致**（对 Q8_0 参考的解码路径 KLD 每一位数字都不变），实用解码从 **32.30 → 35.25 tok/s**，且从 42 token 到 11k token 的提示词上提升均匀一致。文档里记录了在 ggml 计算图中做任何融合之前都值得知道的一个陷阱：跳过节点会改变分配器对"谁还活着"的判断——忽略这点的版本快了 1.7%，但是错的。[`docs/delta-net-fusions.md`](docs/delta-net-fusions.md)

补丁 `0010` 的代码是 **[Kmic-68](https://github.com/Kmic-68) 的工作**，来自他的 fork [github.com/Kmic-68/llama.cpp](https://github.com/Kmic-68/llama.cpp)；补丁由 qr0n 从该仓库整理而成。它为 Pascal 提供了面向长 prefill 的 cuBLAS-GEMM flash attention——在 tile 内核只能跑到显卡 fp16 速率零头的场景下补位。它还添加了把 Qwen3.8-27B 在 `-sm tensor` 下每个 KV 头的全部 6 个 query 头折叠进去的 tile 内核。本机成绩：**32k 深度 prefill +23.6%**，困惑度不变。[`docs/long-context-attention.md`](docs/long-context-attention.md)

补丁 `0011` 面向**并发 agent**：`llama-server --parallel N` 每步为 N 个序列各解码一个 token。`0007`-`0009` 的大部分在该形状下选择放弃、回退原版内核。`0011` 把 fp16 matmul、就地状态读取与融合归一化扩展到该形状，并修复了一个谓词加载把每个激活取四遍的 Q6_K 内核。qwen3.8-27b 上四个 agent 从**单体 16.0 提升到 20.3 tok/s**。文档覆盖了就地状态读取在单序列下不可能、多序列下却可能出现的竞态：循环内存会重排 cell。[`docs/concurrent-decode.md`](docs/concurrent-decode.md)

补丁 `0012` 把 `0010` 那个特殊的 GQA-6 flash-attention tile 阶梯限定在 GP100。`0010` 的 `launch_fattn<256, 8, 6>` 配置在 sm_61 的 P40 上占用率为零，会触发启动断言。其他架构现在改用既有的 2 的幂阶梯，其双头内核即可处理 GQA=6。Q4_0 direct-tile 与 staging 检查使用同一个 GP100 门，保证分发与分配一致。

`0001` 与 `0002` 合计在两个文件里新增 61 行：一个架构中立，另一个由 GP100 门保护、在其他所有卡上 SASS 逐字节相同。`0003` 与 `0004` 都在 `allreduce.cu`，只影响双卡的 `-sm tensor`。

**最大的单项收益不需要补丁——只要一个旗标。**用 `f16` KV 代替 `q8_0`：

| 模型 | 配置 | 之前 | 之后 | |
|---|---|---|---|---|
| Qwen3.8-27B Q4_K_XL | 真实 74,919-token 请求，tg | 16.85 tok/s | **20.92** | **+24.1%** |
| Qwen3.8-27B Q4_K_XL | 同请求，prefill | 271.59 tok/s | 272.40 | +0.3% |

量化 K 会让注意力的 K·Q 点积走 `ggml_cuda_dp4a`，而 sm_60 用四次标量 int8 乘加模拟它；F16 K 则走 packed fp16 单元——GP100 有，其他 Pascal 没有。它多读 52% 的内存，依然更快。详见 [`docs/kv-cache-type.md`](docs/kv-cache-type.md)——包括它**不**适用的场景（投机解码）以及一个本可更好但会崩溃的变体。

减少内核启动次数的优化在本项目里战绩毁誉参半，这段战绩值得完整读一遍。CUDA graphs 在双卡机器上**落选（−1.4%）**、在四卡机器上**大赢（+15% 到 +149%**，见下文 `GGML_CUDA_GRAPH_FORCE` 专节）；MMVQ 融合**落选（−2.1%）**。"减少启动次数一无所获"这种一揽子说法是错的，它的反面同样错——后来一个每 token 去掉 128 次启动的融合，对墙钟时间的改善约是对内核时间的 4 倍——因为省下的是内核*之间*的间隙，profiler 的内核时长看不到它。准确的规则：只有当减少启动不给热循环增加工作时它才划算——而且它去掉的每次启动的宿主税越大，收益越大。这棵树的 graph 机器把自身开销摊薄（两次暖启动、按 uid 键复用、仅在节点属性变化时 `cudaGraphExecUpdate`），重放不进热循环；四卡机器每步的宿主活远多于双卡机器，双卡机器的宿主活较少，而 MMVQ 融合在任何机器上都给受限于发射（issue-bound）的循环加谓词。历史调查见 [`docs/negative-results.md`](docs/negative-results.md)。

## 为什么 P100 是特例

GP100 是唯一既有**全速 fp16 又没有 `__dp4a`** 的 Pascal。`__dp4a`——llama.cpp 所有量化 CUDA 内核赖以构建的 4 字节点积——sm_61 起才有。P100 是 sm_60，只能用四次标量 int8 乘加（每条一个 `XMAD`）模拟它。 用 `bench/sweep.cu` 在本卡实测：

| 工作负载 | 吞吐 |
|---|---|
| fp16（packed `half2` FMA） | **15.80 TOP/s** |
| fp32 | 8.68 TOP/s |
| **int8（4 字节点积，模拟）** | **3.95 TOP/s** |
| int32（XMAD） | 2.81 TOP/s |

**fp16 的吞吐恰好是软件模拟字节点积的 4.0 倍。**llama.cpp 的量化内核假设恰恰相反——int8 便宜、fp16 昂贵——因为商业上重要的 Pascal 机型是 P40（sm_61）：它有 `__dp4a`、fp16 被阉割。CUDA 后端里每一个按 Pascal 划分的决策都继承了这个假设，而在 GP100 上其中好几条是错的。

## 真正的瓶颈

不是带宽。把 `mul_mat_vec_q`（占解码时间 92.4%）对照实测 607 GB/s 的 HBM2 读上限剖析：

| | 实测 | 上限 | |
|---|---|---|---|
| 内存带宽 | 165.8 GB/s | 607 GB/s | 27% |
| int8 MAC 速率 | 0.274 T MAC/s | 1.98 T MAC/s | 14% |
| **warp 指令发射** | 1.13-1.47e11/s | 1.487e11/s | **76-99%** |

内核**受限于指令发射**，每权重花 **9.25 条 SASS 指令**，解码墙钟时间内 GPU 忙碌 97%。所以杠杆是指令*数*：削减几乎 1:1 换成加速，且带宽仍有约 3.6 倍余量。

## 具体改动

**`patches/0001`——停止重复计算 q8_1 块和。**`vec_dot_q4_K_q8_1_impl_vmmq` 对每个输出行都通过 `dp4a(0x01010101, u, ...)` 重算激活字节之和。这个和与权重行无关，`block_q8_1` 早已把它存在 `ds.y` 里——兄弟函数 `..._impl_mmq` 读的正是它。四个线程覆盖一个 q8_1 块，现在恰有一个贡献 min 项。每 16 权重 148 → 138 条指令。**+4%。** 架构中立：它在所有地方每次调用省 4 个 `dp4a`，只是在模拟 dp4a 的卡上最值钱。不逐位一致——`ds.y` 是原始浮点之和而非 `d * sum(quants)`——但这是 `..._impl_mmq` 本就采用的近似，且可以说更忠实，因为它省去了一次量化往返。

**`patches/0002`——GP100 的 MMVQ 参数表。**`calc_rows_per_block` 在 `ncols_dst == 1` 时返回 1，于是每个输出行都重新加载、重新解包同一批激活。一张 `MMVQ_PARAMETERS_PASCAL` 表（由 `__CUDA_ARCH__ == GGML_CUDA_CC_PASCAL` 保护，即仅 GP100——sm_61 保持通用路径）让 K 量化每块 4 行，跨行共享这份工作。`calc_rows_per_block` 增加一个 `ggml_type` 参数，与 `calc_nwarps` 对齐。**这是大头。** 每块行数扫描，单卡 tg128，已应用 0001：

| rows | 1 | 2 | **4** | 8 |
|---|---|---|---|---|
| tok/s | 40.82 | 48.31 | **52.23** | 51.30 |

K 量化用 4；旧式量化保持 2，因为在 4 时恰好一个用例（`MUL_MAT type_a=q4_1, n=1`）漂移到 NMSE 6.93e-4，超出 `test-backend-ops` 的 5e-4 限。按现设全过。

**`patches/0003`——在 Pascal 上启用内部 AllReduce。**`ggml_cuda_ar_pipeline_init` 曾拒绝一切 Volta 之前的设备，注释写"the chunked kernel uses `__nanosleep`, which is sm70+"。这是 `allreduce.cu` 里唯一的 Volta 专属构造：传输本体是映射的 pinned 主机内存，到达标志是普通 `volatile int` 配 `__threadfence_system()`——按该文件自己的注释，这是为"没有 NVLink 的 PCIe 直连 GPU"选的——而 `ggml_cuda_get_max_cpy_bytes()` 在 Volta 前本就返回 8 而非 16，向量宽度自适应。 这个门失败意味着 `-sm tensor` 落到 `try_allreduce_butterfly`——一个返回 `false` 的桩——于是每层边界都由 ggml 调度器的通用 inter-backend 拷贝服务：**f32、走主机内存、外加单独的 add 内核。**在一个全 GPU 驻留 27B 的 2048-token prefill 上，计时窗口的 nvprof 轨迹显示 **256 次 D2H 与 258 次 H2D 传输，每次恰好 40.0 MB——20.5 GB 的 PCIe 流量，占 GPU 时间的 23.1%。**（40 MB = 2048 token x 5120 embed x 4 字节。计数为两卡之和：每卡 128 = 64 层 x **每层 2 次交换**，张量并行的最小值——一次在 attention/linear-attention 输出投影后，一次在 FFN 后。） 补丁把 Volta 前的 `__nanosleep(100)` 换成等时长的 `clock64()` 延时循环，并把门槛降到 `GGML_CUDA_CC_PASCAL`。新增 20 行。**在 GP100 上测试；sm_61 共享该代码路径但没有卡可用。**

注意两次收益的机理不同。Prefill 张量高于 1 MB 的 `copy_threshold`，走 copy-engine 路径，收益来自 bf16 线格式把字节减半。生成张量低于它，走融合 chunked 内核，收益来自融合——并且关掉 bf16 线格式后依然成立，即逐位精确。

**`patches/0004`——copy-engine 的 H2D 用独立流。**`0003` 就位后，prefill 量级的交换走 copy-engine 路径：每卡把部分和拷到 pinned 主机内存（D2H），再拉回对方的（H2D）。两者原本发在同一个流上，于是**每卡一次只能拷一个方向**，尽管 P100 有两个拷贝引擎（`asyncEngineCount = 2`）。2048-token prefill 的轨迹显示每卡 642 ms 的拷贝零重叠，占墙钟 12.2%。一个 2 MB pinned 拷贝（AllReduce 用的块大小）的独立测试：双流双向 55 ms，对串行的 100-111 ms（含跨插槽）。 补丁让 H2D 拥有自己的流，并用显式事件保住单流时代隐式给到的每个顺序。其中一个顺序容易漏：计算流必须等本卡*自己的* D2H 完成，而不只是对端数据到达——因为 add 内核写的正是 D2H 正在读的缓冲（bf16 路径上那缓冲是池分配、返回即释放）。**缺了这条边的构建一样快，但困惑度是 7.68 而不是 3.53。**llama-bench 看不见它；困惑度能。架构中立——任何走 copy-engine 路径的多卡 `-sm tensor` 配置都应受益——但只在本机测过。

**同一次调查还得出一个警告：**llama.cpp 只在设置了 `GGML_CUDA_P2P` 时启用 peer access。在这台双插槽 P100 机器上，开它是 **10.7 倍的倒退**（pp2048 357.34 → 33.45），尽管 `cudaDeviceCanAccessPeer` 两个方向都返回 true。跨 UPI 跳的 peer access 在这里是病态的。

## 验证

- `test-backend-ops test -b CUDA0 -o MUL_MAT,MUL_MAT_ID`——**1855 通过，0 失败**
- 困惑度前后**小数点后四位一致**（5.8938 ± 0.06590）
- 补丁 0002 在 sm_61 与 sm_75 上产生**逐字节相同的 SASS**——GP100 之外的严格空操作，用编译两棵树再 diff `cuobjdump -sass` 验证
- 基准从匹配的起始温度起跑；这些卡约 60 秒后热节流，否则会悄悄污染 A/B 对比

对 `0003`（改的是传输而非内核）：同一语料上困惑度 **3.5372 ± 0.06192（前）、3.5330 ± 0.06180（后）**，设 `GGML_CUDA_AR_BF16_THRESHOLD=0` 时为 **3.5372 ± 0.06192——恰为基线**。最后一行证明传输改动在数值上精确；中间行的差值仅是上游默认 bf16 线格式所致，约为一个标准误的 7%。还检查了新自旋循环的生成 SASS，确认 `clock64` 退避未被消除、warp 重汇聚用 `@!P2 SYNC`。 `0003` 后来做了 **Volta 前死锁风险审计**（sm_70 以下无独立线程调度）：每块只有 lane 0 自旋、它轮询的标志由*对端 GPU* 写、两个屏障都以收敛态到达（SASS 证据）。它的小张量路径也做了精确性检查——强制所有归约走它：困惑度 3.5372 / 3.5330，与 copy-engine 路径一致。三个并发客户端的 35 分钟浸泡干净跑完。

对 `0004`：两种线模式下困惑度与仅 `0003` 一致（3.5330 / 3.5372）；256-token temp-0 输出逐字节一致；第二次 35 分钟并发浸泡干净（68 个请求，0 挂起，输出与 pre-`0004` 构建逐字节一致）。`0001..0006` 全系列用 `git am` 打到 `b10660` 上，逐字节复现被测树（2026-09-18 复查；该树即本仓库的 `llama.cpp/`）。

## 自行应用补丁

自带 `llama.cpp/` 加 `./build.sh` 是省事路线。要打到你自己的 checkout 上，基线为 llama.cpp `b10660`（commit `6c84c7d`）：

```
git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
git checkout b10660
git am /path/to/patches/*.patch

cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=60 \
  -DCMAKE_C_COMPILER=gcc-13 -DCMAKE_CXX_COMPILER=g++-13 \
  -DCMAKE_CUDA_HOST_COMPILER=g++-13
cmake --build build -j$(nproc)
```

CUDA 13 移除了 Pascal，请用 **CUDA 12.x** 构建。12.4 的 `nvcc` 拒绝 gcc-15，故显式指定 gcc-13。

## 仓库里还有什么

| 路径 | |
|---|---|
| `llama.cpp/` | 上游 `b10660` + 各补丁，可直接构建——本分支请见快速开始中的树状态说明 |
| `build.sh` | `llama.cpp/` 的 CUDA 12 / sm_60 构建；`CUDA_ARCH`、`JOBS` 可覆盖 |
| `tools/verify-source.sh` | 从上游 + `patches/` 重新推导 `llama.cpp/` 并 diff |
| `bench/sweep.cu` | GP100 自校验的算术与带宽扫描——上文 fp16 对 int8 数字的出处 |
| `tools/ggufinfo.py` | 零依赖 gguf 解析器；为 roofline 工作打印每 token 精确读取字节（不是文件大小——要减去 `token_embd`） |
| `data/q4k_one.sass` | Q4_K MMVQ 内核的基线 SASS 提取 |
| `docs/` | 完整调查、方法与功耗/热学发现 |

## 方法说明

真正起作用的一步是**归因实验**：把内核的每个子表达式分别删掉、编译变体、diff SASS。三次 100 秒的构建推翻了当时的工作假设——冗余和被认为花约 16 条 XMAD，实际只花 6，因为 nvcc 把乘 1 折叠掉了。没有这一步，力气会花在 4% 的改动上而不是 33% 的那一个。 单翻译单元迭代让它变得便宜：从 `build/compile_commands.json` 里抽出确切的 `nvcc` 命令行，一个翻译单元约 100 秒重建，对整个库的约 20 分钟。

## 适用范围与注意事项

- 实测环境为两块 Tesla P100-PCIE-16GB、CUDA 12.4、驱动 580、Ubuntu、双 Xeon Gold 6148。别处的数字会不同；*分析*应适用于任何 GP100。
- 补丁 `0001` 与 `0002` 只管解码。sm_60 上的稠密 prefill 走 cuBLAS（`ggml_cuda_should_use_mmq` 把 MMQ 限制到 MoE），而 cuBLAS `hgemm` 已跑在这张卡真实 fp16 峰值的约 80%（1325 MHz 下 19.0 TFLOP/s——上面的 15.80 TOP/s 是一次被节流的微基准），所以对这两个补丁，任何 `pp` 变化都应视为倒退信号。`0003` 与 `0004` 是例外：它们是多 GPU 传输修复（`0004` 只动 `pp`）。单 GPU 上无效果，`-sm layer` 下也无效果（它不做 allreduce）。
- **本项目帮助 GPU 驻留模型。对 `-ncmoe` 的 MoE 无帮助。**在一台专家驻留系统内存的 176B-A3B 上剖析：GPU 时间的 75% 是一次性模型上传，生成由 CPU 就地计算 48 层中的 30 层专家主导，端到端效果低于该配置约 13% 的跑间噪声。这里没有任何东西改变主机侧路径。
- 每块行数按量化*类型*调优，正确值依赖类型：K 量化要 4，其余 2，两者都 1 是上游现状。"Q4_K_XL" 模型并非全是 K 量化——Qwen3.8-27B 仅 `iq4_xs` 就占解码约 7%，这正是非 K 值重要、在那里值约 4% tg 的原因。
- 决定**不向上游提交**。它们以针对固定 llama.cpp 版本的补丁形式存放在此。

## 本分支（key-sh）：FA-GEMM 默认 fp32——fp16 NaN 修复

补丁 `0010` 的 GEMM flash attention 提供两种精度模式；在本分支之前（Kmic-68 原版与 qr0n 的树）默认使用 fp16 模式——`COMPUTE_16F` cuBLAS 调用、fp16 累加、fp16 S/P 暂存。**在本机上，该 fp16 路径会产生 NaN。**

环境：2x P100-PCIE-16GB、qwen3.8-27B-UD-Q8_K_XL、`-sm tensor 16,16 -fa on`、f16 KV cache、ubatch 1024。症状：足够长的提示词在 prefill 期间输出退化为纯 `?` 文本，非确定（同提示词、同种子，不同次启动结果不同），且损伤持续——一次被毒化的 prefill 之后，连 11-token 的请求也返回 `?`，因为写入 f16 KV cache 的 NaN 会被 iSWA 层复用，直到重启。

整个排查期间的触发统计：3,839-token 提示词从未毒化（任何构建上 0 发）；3,866-token 提示词 6 发中 3 发毒化；7,695-token 提示词在三个 fp16 路径构建上 11 发全毒。

实验排除（各自独立构建 + 触发发数）：QKᵀ 输入预缩、输出还原 x16（无效——非幅度/溢出问题）；从 PV GEMM 移除 `CUBLAS_GEMM_ALGO4`（无效）；PV 精度本身（强制走精度*更差*的 `CUBLAS_GEMM_DEFAULT` 长链，毒化率不变）。**最终剩下的唯一嫌疑：**闭源 cuBLAS fp16 `hgemm` 内核本身——问题出在该路径会用到的两个矩阵形状上（m=2048, n=6144, k=256 与 m=256, n=6144, k=2048）——幅度无关、形状依赖、逐次不定。这只是一个假设而非定论；内核闭源，源码层面的排查到此为止。

本分支的修复：**FA-GEMM 路径默认 `COMPUTE_32F`**——QKᵀ 与 PV 均 fp32 累加，S/P/O 暂存 f32。逃生门：`GGML_CUDA_FA_GEMM_PREC=16` 回到 fp16 路径（一个环境变量、免重编——便于将来重测新版 cuBLAS）；`GGML_CUDA_FA_GEMM=0` 整路禁用 GEMM 路径（上游 tile 内核）。PV GEMM 同时限定 `CUBLAS_GEMM_DEFAULT`（移除 ALGO4；对本 bug 无行为影响，作为简化保留）。这些改动以分支上的源码编辑存在，而非编号 `.patch` 文件；完整实验台账记录在提交信息中。

### 本机实测记录

全程同一机器、同一组旗标（2x P100-PCIE-16GB、qwen3.8-27B-UD-Q8_K_XL、`-sm tensor 16,16`、`-fa on`、f16 KV、ubatch 1024）：

| 路径 | 3,839-token 提示词 | 3,866-token 提示词 | 7,695-token 提示词 | 解码探针（n=1） | 7,695 请求的 pp |
|---|---|---|---|---|---|
| fp16 默认——三个构建：原版 / 预缩 x16 实验 / 移除 ALGO4 | 每发皆净 | 6 发中 3 发毒化 | **11 发全毒** | 每发皆净 | 248 / 250 / 251 tok/s |
| fp32（env `GGML_CUDA_FA_GEMM_PREC=32` 强制）——两个构建：原版 / 移除 ALGO4 | 净 | 净 | 净 | 净 | 246 / 246 tok/s |
| **fp32 默认（本分支，无任何环境变量）** | 净 | 净 | 净 | 净 | 244 / 245 / 246 tok/s |

整个排查期的毒化总计：3,839-token 提示词——任何构建上均为 0 发；3,866——6 发中 3 发；7,695——fp16 路径 11 发全毒。解码（n=1）在任何构建、任何路径下从未毒化——暴露面是 prefill。上游 tile 路径（不含 `0010` 的构建，以及 `GGML_CUDA_FA_GEMM=0`）同样从未毒化——bug 特异于 GEMM 路径。

代价：8k 上下文 prefill 约 **1.5%**——同一 7,695-token 请求的对跑均值：fp32 为 245.4 tok/s（244-246），fp16 约为 249（248-251）。代价之所以只有这么低，原因就写在 `fattn-gemm.cu` 的精度注释里：在 `nt x gqa = 1024 x 6 = 6144` 时，fp16 的 PV GEMM 本就运行慢速 `DEFAULT` 长链，该形状下 fp16 模式的速度优势大半不存在。（[`docs/long-context-attention.md`](docs/long-context-attention.md) 里的 +11%/+27% fp32 代价在 16k/64k 深度——那里才存在。）

验证：fp32 路径从未产生过 NaN——**七次服务启动、三个构建、24/24 触发请求全净**（两次在 fp16 默认构建上、两次在中间的移除 ALGO4 构建上，均强制 `GGML_CUDA_FA_GEMM_PREC=32`；三次在 fp32 默认构建上，完全无环境变量）；解码（n=1）在任何 fp16 测试中从未毒化；fp32 同时是更精确的路径（Kmic-68：严格优于上游 tile 内核）。

## 本分支（key-sh）：`GGML_CUDA_GRAPH_FORCE`——Volta 前显卡的 CUDA graph 解锁

上游 CUDA 后端的 graph 机器——流捕获、按 uid 键的图缓存、两次调用的暖启动、形状稳定重放用的 `cudaGraphExecUpdate`——在这棵树里一应俱全，却被 `ggml_cuda_graph_set_enabled` 里的一道检查挡在 Volta 之下（`cc < GGML_CUDA_CC_VOLTA`）。在 P100（sm_60）上，这意味着机器已编译进来却从未运行过：本机有史以来的每一条 profiler 轨迹里 `cudaGraphLaunch` 都是零。解锁以三行源码编辑的形式随本分支交付（`llama.cpp/` 内提交 `3d19fc4`，`ggml-cuda.cu` +3/−1），外加一个环境变量：

- `GGML_CUDA_GRAPH_FORCE` 未设、为空或为 `0`——行为与没有这个编辑的构建逐字节一致；已在本机复验（smoke 运行与一个完整 A/B 臂均与补丁前构建吻合）。
- 任何其他值——跳过架构门禁，graph 管线在 Volta 之前的硬件上运行。其余一切不被绕过：管线自身的节点兼容性检查照常执行，内部 AllReduce 继续在图外运行（它经调度器的 comm 接口 `ggml_backend_comm_allreduce_tensor` 发出），因此捕获区内不会出现 AllReduce 的宿主同步调用。

四卡机实测（4x Tesla P100-PCIE-16GB 物理四卡、`-sm tensor -ts 16,16,16,16`、`-c 4096 -fa on`、f16 KV、`-p Hello`、`--temp 0`、llama-cli `-st`；单位 tok/s）：

| 模型 | 长度 | 图关闭 | `GGML_CUDA_GRAPH_FORCE=1` | Δ | 输出校验 |
|---|---|---|---|---|---|
| qwen3.8-27B-MTP-Q8_0 | tg128（MTP，3 tok/步） | 34.13（7 次运行，33.8-35.6） | **39.30 ± 0.15**（3 次） | **+15.2%** | MD5 一致，双设置共 4 发 |
| qwen3.8-27B-MTP-Q8_0 | n=2048 | 33.4 | **40.1** | **+20.1%** | — |
| qwen3.8-27B-UD-Q8_K_XL | tg128 | 32.5 | **37.4** | **+15.1%** | 文本一致 |
| qwen3.8-27B-UD-Q8_K_XL | n=2048 | 32.4 | **37.9** | **+17.0%** | **MD5 一致，全程 2048 token** |
| qwen3.6-35B-A3B-UD-Q6_K_XL（MoE，3B 激活） | tg128 | 33.6 | **78.4** | **+133%** | 文本一致 |
| qwen3.6-35B-A3B-UD-Q6_K_XL（MoE） | n=2048 | 33.6 | **83.8** | **+149%** | **MD5 一致，全程 2048 token** |

27B-UD 的 `llama-server` 交叉验证（单发、同旗标）：38.52 与 39.85 tok/s，与 cli 数字一致。（本节早先版本曾把 slot 日志的 `graphs reused = 127/128、253/256` 计数当作 CUDA graph 重放的证据；那个读法是错的——该计数统计的是 llama 侧计算图复用，图关闭时同样约每 token 加一。证据应当是成对的速度差，或 nsys 的 `cudaGraphLaunch` 计数。）

**Server 绝对值随操作点浮动；判定看成对差值。**上表是 llama-cli 微基准操作点：裸的单 token 提示词、`--temp 0`、贪心采样、无流式。真实 server 请求带着完整采样链（top-k/top-p/min-p/重复惩罚/DRY）、流式推送，以及生成过程中不断增长的上下文，绝对值会相应下移。本机的成对 server A/B（同一条 378-token 提示词、temp 0.8、webui 请求、tensor 分配，每模型两轮独立复测）：

| 模型 | server 无图 | server `FORCE=1` | server 比值 | cli 比值 |
|---|---|---|---|---|
| qwen3.8-27B-UD | 21.9 与 22.9 | 32.2 与 32.5 | **1.42-1.47 倍** | 1.15-1.17 倍 |
| qwen3.6-35B-A3B | 23.2 | 61.5 | **2.64 倍** | 2.49 倍 |

server 比值*优于* cli 比值，原因还是那笔宿主税换了顶帽子：无图时，每次响应多出的约一万次启动调用落在一条更贵的宿主路径上（slot 排队、流式、采样线程竞争），无图臂被罚得比裸 cli 循环更重——27B 无图从 cli 的 32.5 掉到 server 的 22.9，图臂几乎不动。绝对值仍吃操作点折扣（A3B 在 server 为 61.5，对照 cli 最优 83.8）：每请求的宿主地板——采样、流式、以及留在图外的 AllReduce 入队路径——大致与模型无关，于是它在 GPU 活最少的模型上咬掉相对最大的份额。同一批运行还带出两条结构性结论。其一，无图时本机解码速度与模型无关：3B 激活的 MoE 23.2 t/s 与 27B 稠密的 22.9 同速——定地板的是宿主 API 节拍，不是 GPU 的活。其二，图进场后分配模式发生翻转：无图时 `-sm layer` 在 MoE 上胜过 `-sm tensor`（50.3 对 23.2），因为它从不运行 AllReduce、整个躲开了入队税；图开启后 tensor 反超（61.5 对 52.5-58.6），因为重放已把启动节拍收编、宿主只剩 AllReduce 入队。**tensor 分配才是图解锁红利最大的地方。**

为什么差距这么大。没有图时，本机的解码速度几乎与模型无关——34.1（27B 稠密+MTP）、32.5（27B 稠密）、33.6（3B 激活 MoE）——因为定地板的是宿主侧 API 节拍，不是 GPU 的活。图把这份节拍的大头收编。nsys 对一次 1536 轮的 27B 剖析：约 2.25 万次内核启动调用收拢为 3612 次图重放（全程 LaunchKernel 调用 −27%）；轮内内核间宿主间隙从 ~1.8-3.1 µs 缩到 ~1.3 µs；四设备起始瀑布每轮从 0/14.8/34.3/67.3 µs 压到 0/10.8/19.3/40.9 µs；平均解码轮从 ~651 µs 降到 ~570 µs。最后这个数字是先按启动次数预测（每轮 −88 µs）、后实测（−81 µs）的——误差约 10%，也是本结果里最应能迁移到别的机器的部分。收编之后剩下的是各模型真实的 GPU 活——MoE 的活小（3B 激活参数、专家驻留各卡本地），所以它的天花板远高于稠密模型。

没够到的地方：AllReduce 的入队路径仍在宿主上（每轮每设备约 22 µs）——这是实测后的决定。把 AllReduce 收进图的原型已经打通且逐位一致（每次交换一张多设备图、设备侧到达计数器、四卡验证通过），但本机的 `cudaGraphLaunch` 地板约 25 µs、**与节点数无关**（9 节点的探针图与 115 节点重放图的 ~24 µs 相同），对上它所要替换的四次内核启动（~27 µs）最好也只是打平、最差倒亏——交换因此留在图外。prefill 同样不受影响（本已 GPU 饱和；1-token 提示词测出的 prompt 数字两边都是固定开销噪声）。

正确性：以上每个 A/B 都在 `--temp 0` 下运行，两臂输出**逐字节一致**——n=128 全文 MD5（27B-MTP：双设置共四个相同哈希），两个日常模型各做了 n=2048 全程 MD5（27B-UD：`ECA65C64...`；35B-A3B：`3C95B9ED...`）。验证期间有一个输出看着吓人——n=2048 时刷出 emoji 图鉴——但**无图臂产生了逐字节相同的输出**，所以那是采样设置、不是图路径：`--temp 0` 加 `--ignore-eos` 加裸 "Hello"，在模型用 emoji 结束一个句子后，贪心解码就滑进复读吸引子。正常采样、EOS 开启不会进入该形态；若见到此类螺旋，先怀疑采样参数再怀疑构建。

与 MTP 的关系：图收益不依赖投机解码（上表 27B-UD 两行都是单 token 步），也不动 MTP 的盈亏线：图把每个解码轮等比例变便宜，而接受率门槛（3 个草稿接 ~2 个）是两个"被图变便宜的量"之比。草稿接受率低的真实负载上，MTP 关掉、图收益照拿。

用法：Windows 下 `set GGML_CUDA_GRAPH_FORCE=1`（单窗口）或 `setx GGML_CUDA_GRAPH_FORCE 1`（永久）；Linux 用 `export`。不设 = 与旧构建完全一致。

**图开启时的退出耗时。**在本机上，`GGML_CUDA_GRAPH_FORCE=1` 时按 Ctrl+C 需 40-55 秒才回到提示符，图关闭时不到 1 秒，与模型无关：四张卡上缓存的图工单要在退出时逐张同步销毁，而每次销毁在这个 pre-Volta 驱动上都很贵。这纯粹是退出环节的事——运行性能、计时输出与结果都不受影响（日志在延迟开始前就打印完毕）。日常使用建议用 `taskkill /f /im llama-server.exe` 停服（多实例时用 `/pid` 指定进程，请求进行中不要杀）；llama-server 没有任何持久化状态——模型、KV cache 与图全部驻留显存、随进程消亡，驱动会回收干净，下次启动如常。

**`--batch-size` / `--ubatch-size` 简说。**`ubatch` 是 prefill 内核每次启动实际计算的物理微批；激活显存随它线性增长（本机在 4096、预留 262k 上下文时每卡约 14/16 GB）。`batch` 是调度器跨 slot 可累计的逻辑排队深度——显存代价近乎为零，但必须 ≥ ubatch；取 2-4 倍 ubatch 是常规选择。两者都**不**影响 token 生成：解码时每步最多 `--parallel` 个 token 过 GPU，与 ubatch 设多少无关（27B 在 ubatch 2048 与 4096 下实测相同）。它们只在 prefill 超过一个 ubatch 的长提示词上起作用——更大的 ubatch 减少每批的 AllReduce 往返轮数——但在本就跑 cuBLAS 的路径上收益递减，且显存账单是真实的。

### 同时随本分支入库：AllReduce P2P staging（默认关闭）

提交 `32b9763`（allreduce.cu，+63/−2）为内部 AllReduce 增加了点对点 staging 变体，`GGML_CUDA_AR_P2P`（自提交 `6fb569d` 起默认**关**）：初始化时对每一对设备探测 `cudaDeviceCanAccessPeer`，接受的对启用 peer access，任何一对被拒绝则**整体**回退到既有的 copy staging。设 `GGML_CUDA_AR_P2P=1` 可显式启用。
为什么翻转默认。该变体只在全 peer（all-peer）拓扑上才会激活——这台双插槽四卡机上所有跨插槽对都被硬件拒绝（`can = 0`），所以它在四卡机上从不激活（上文每个 MD5 门下输出都逐字节一致）。本机唯一的全 peer 布局——同根的三张卡（暴露为设备 1,2,3）——端到端测试暴露出两个相互独立的缺陷：MTP 投机解码下**draft 起步即崩**（案例 `32b9763`，稳定复现）；而默认翻转后强行设 `=1` 则死得更早——模型加载即崩，sticky CUDA 错误 `peer access is already enabled`（init 路径上的重复 enable，在第一个被检查的内核启动处引爆）。两个根因均为归因结论、未证明到指令级（嫌疑：Pascal 对端设备内存写入的序语义；重复 enable）。同一三卡布局的 copy staging 路径不受影响——也就是现在的默认路径：256 token 跑满、文本逐字节一致、41.3 tok/s。两点长期注意：它与上游的 `GGML_CUDA_P2P` 旗标无关——那个管的是调度器的通用 peer 拷贝，其 10.7 倍跨插槽倒退记录在上文；机制不同、代码路径不同。而且在硬件*接受*跨插槽 peer access 但服务它病态的机器上（本 README 早年所在的双卡 UPI 机器），默认关现在也保护了那台机器——只有显式 `=1` 才会激活 staging，设 `GGML_CUDA_AR_P2P=0`（或不设）免重编恢复。

## 致谢

llama.cpp 为 MIT 许可，© the ggml authors。本仓库的补丁针对它，携带相同许可。调查过程与代码、文档写作大量使用了 AI（Claude）；补丁中的 `Co-authored-by` 尾注记录了这一点。

`p100-gp100-fp32` 分支的新增内容——FA-GEMM 的 fp32 默认、ALGO4 移除、`mmvq-gp100` 的 GLU 守卫、上文的 NaN 调查、`GGML_CUDA_GRAPH_FORCE` 的 Volta 前图解锁、以及 AllReduce P2P staging 变体——为 key-sh 的工作（2026-10），适用相同许可。

---
## GP100 (sm_60) cuBLAS fp16 修复 —— 上游 #25593 收窄裁剪（2026-10-17）

**一行修法**：fast_fp16_hardware_available() 排除 cc==600，P100 的 cuBLAS GEMM 改用 FP32 累加，替代被静默污染的 FP16 路径；decode 侧（MMVQ、FA tile、mmvf）设计上零波及。

**为何收窄**：上游标准三行修法（编译期整体关闭 FAST_FP16_AVAILABLE）会连带杀死 0007 号补丁在 sm_60（无 DP4A）上的 2.03x MMVQ 收益；本修法收窄到 cuBLAS 唯一调用点（ggml-cuda.cu:1627/1628；MMQ 调用点在 sm_60 不可达）。

**四卡 P100 KLD 审计**（16 分块 KL 对账，真值基座 = f32 KV / -fa off，语料 = 108KB server README）：

- Mean KLD 0.003704 -> 低于显示精度；全部分位提升 >= 1000 倍（最大 KLD 0.501 -> 0.000055）
- Same-top-p 98.064% -> 100.000%（修复前 1.94% 的 token argmax 被换）
- RMS dP 2.240% -> 0.001%；PPL 税 +0.35% 免除（PPL(Q)/PPL(base) 1.0035 -> 1.0000）
- decode 速度设计上不变；prefill 落内容相关噪声带（±6%）内

**golden 探针注记**：11-token 贪心 MD5 探针修复前后位级相同（探针盲区：短 prompt 极少命中毒位）。上表 KL 面板为权威证据。

**披露**：GGML_CUDA_FA_GEMM_PREC=16 逃生门设计上被强制回 FP32（ggml-cuda.cu:1628 守卫）。

---

## 本分支（key-sh）：宿主侧解码补丁系列（sbp 11/13/21），2026-10-18

上游 fork 作者 qr0n 维护一组宿主侧系列补丁（sbp 系列），瞄准解码编排路径。其中三件已以三个 commit 落地本分支：f5aadb6（#11 penalties-direct）、164a88e（#13 sampler-prefilter）、d59c2f8（#21 sched-reset-lazy）。三者皆为纯宿主/C++ 改动：无意改动内核与数值，实测也确认无。

**四卡机实测**（4x P100-PCIE-16GB、-sm tensor -ts 16,16,16,16、qwen3.8-27B-UD-Q8_K_XL、ctx 262144、ubatch 1024、batch 4096、threads 20、完整采样链（含 penalties 与 DRY）、GGML_CUDA_GRAPH_FORCE=1、llama-server、256-token 探针；ABBA 设计、双会话）：解码 34.47 → 36.35 tok/s = **+5.46%**（两配对臂 +6.16% / +4.77%；全部 12 读 OLD 与 NEW 分布零重叠；第二会话复现 +5.52%）。prefill 持平—这正是宿主编排绑定型解码应有的机制指纹（本机解码墙钟的 55-60% 为宿主空转；机理工作见 HANDOFF.md v8.1）。

**操作点说明**：以上绝对值与上文 GGML_CUDA_GRAPH_FORCE 表不可直接比较（上下文长度、拆分、采样链与探针形态均不同）；按本 README 一贯规则，判定看成对差值。

**位级正确性**（三件叠加 vs 打补丁前构建；贪心与全采样链两条路径）：128-token 贪心输出 MD5、64 个位置 top-10 全概率数组（位级 KLD 等效）、跨请求 slot 状态探针（同一缓存 slot 连发两个不同提示词、第二发输出逐字节一致）—全部逐字节一致。调度器改动未扰动图复用计数（254/507，跨会话不变）。

**放大说明**：系列作者在单卡机上实测 #21 单件 +0.94%；本机效应约为其 4 倍，与四路张量并行解码受宿主编排绑定一致—每步有更多宿主活可供这些补丁去除。

完整方法论（预注册判定带、golden 门校验和、会话日志）：HANDOFF.md 第 7 节（v8.1 增补段）。
