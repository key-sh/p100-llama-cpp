<!-- ===== D:\p100-llama-cpp\HANDOFF.md（v5，2026-10-17）===== -->

# p100-llama-cpp 四卡提速研究 · 交接文档 v5（2026-10-17，key-sh）

> 用途：新聊天窗口起点。v4→v5：**P12 CUDA graph 解锁战役收官**（GGML_CUDA_GRAPH_FORCE 落地，
> 三模型双口径战果+三重位级正确性证据入库 commit 3d19fc4/32b9763/45e9e74 并推送 GitHub），
> README 双文档为权威数据源，本 v5 为索引+路线图+工作协议。
> 排版说明：本文档内所有三反引号均以 xxyyzz 表示（复制后如需还原为 markdown 代码围栏请全局替换回来）。

---

## 0. 新对话工作协议（v5 新增，必读，置于最前）

### 0.1 项目架构速查（v4 缺失导致的重复获取/误判，本轮一次性写清）

- **单仓库结构（R44 实锤，勿再误判）**：D:\p100-llama-cpp 是**一个** git 仓库；`llama.cpp\` 是其中普通子目录
  （内含上游源码+patches+build），**不是嵌套仓库**——在 llama.cpp\ 下执行 git 命令会向上命中父仓库，
  log 哈希与父目录完全一致；push 永远只需一句 `git -C D:\p100-llama-cpp push`。
- **远端**：`myfork` = git@github.com:key-sh/p100-llama-cpp.git（本人仓库，日常 push 目标）；
  `origin` = https://github.com/qr0n/p100-llama-cpp.git（上游作者，**永远不要 push origin**，无权限）。
- **获取现状的标准命令**（新对话开始先跑这一组，勿凭记忆断言）：

```cmd
git -C D:\p100-llama-cpp log --oneline -5
git -C D:\p100-llama-cpp status --short
git -C D:\p100-llama-cpp remote -v
git -C D:\p100-llama-cpp branch --show-current
dir D:\p100-llama-cpp\llama.cpp\build\bin\Release\llama-server.exe D:\p100-llama-cpp\README.md
```

  预期：tip=45e9e74（或更新）；树干净；分支 p100-gp100-fp32；二进制存在。
- **权威数据源**：根目录 README.md / README.zh-CN.md 的《This branch (key-sh): GGML_CUDA_GRAPH_FORCE》专节
  ——本轮全部速度数字、机理数字（launch 收编/AR 残留/退出耗时）、emoji 案、MTP 正交、batch/ubatch 结论都在；
  **README 与本 HANDOFF 冲突时以 README 为准**（随 commit 落库更及时）。
- **避坑三条**：①勿凭记忆断言文件状态（ggufinfo.py "损坏"误判、R43 未验证即断言 commit 在库，均已成认账）
  ——先跑命令看真实输出；②llama.cpp\build 是构建产物目录，bin_old\ 等备份在 D:\temp（易失）；
  ③二进制当前=含 3d19fc4 图解锁的构建，任何 env 未设时行为=旧版逐字节一致（已验证）。

### 0.2 每轮单主攻协议

1. **通读本 HANDOFF 全文**（尤其 §3 路线图与 §5 战役档案）后，分析确定**一个**主攻方向，写明：
   立项依据（引用已有数据）、预期提升百分比（须给出推算过程）、验证门（MD5/golden/冷机 A/B），
   **交用户确认**。不得未经确认直接动手。
2. 用户确认后**立即进入诊断模式**：AI 直接给诊断/测试命令（用户只执行并贴回完整输出），
   AI 解读研判后给下一轮诊断命令；**不要让用户判断结果、写命令或写脚本**。
3. 全部疑问解决后，才提出具体解决方案并实施（独立构建+验证门+冷机 A/B+commit 落账）。
4. 预注册纪律：给命令时同时给"预期结果带"（如 A3B 无图臂 22~30 t/s），实测落带/落带外分别意味着什么，
   先写后测；落带外优先怀疑预期与口径，再怀疑系统。

### 0.3 摘要纪律（上下文受限，强制）

AI 上下文经若干轮会丢失记忆。约定：
- **每轮对话结束时**，AI 在回复末尾输出累积摘要（HTML 注释包裹，形如
  <!-- ===== 交接摘要 Round N ===== ... ===== 摘要结束 ===== -->），内容=上轮摘要全量+本轮增量；
  认账/预注册/结论**只增不删**。
- 用户在**下一轮第一条消息**把上一轮摘要全文贴回。
- 战役收官时（如本轮 P12），AI 另产出 Markdown 收卷摘要 + 更新本 HANDOFF。

---

## 1. 环境与背景

### 1.1 软硬件环境

| 项 | 值 |
|---|---|
| GPU | **4x Tesla P100-PCIE-16GB**，sm_60/GP100，全 TCC |
| 布局 | 插槽 2\|4\|6\|5 → GPU0-3；**GPU0(02:)=CPU1 独居，GPU1-3(81/82/83:)=CPU2 同根复合体**（1+3 布局）；**实测每跨 UPI 跳 ≈3~4% tg** |
| 主机 | X99，双路 E5-2699v3（36C/72T），64GB；**构建 -j 36~48**（nvcc 单文件为主，再大无益） |
| CUDA/驱动 | 12.8 / 573.76（**勿升 13**）；nvidia-smi topo -m 不可用，用总线号判 socket |
| 仓库 | D:\p100-llama-cpp，**单仓库**（见 0.1），分支 p100-gp100-fp32，remote myfork；**已推送至 45e9e74（含 32b9763 P2P staging、3d19fc4 graph unlock、45e9e74 README 终版）；树干净** |
| 模型 | **速度档**：I:\AiModels\001\002\Qwen3.8-27B-MTP-Q8_0.gguf（29G，纯 Q8_0+F32，含 nextn）；**质量主力**：G:\AiModels\001\002\Qwen3.8-27B-UD-Q8_K_XL.gguf（31.5G，90.6% Q8_0+9.4% BF16）；**MoE**：G:\AiModels\001\002\Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf（本轮新入列：图解锁最大受益者 2.5x，tensor+图 server 61.5 t/s）。27B=hybrid 66 层（17 标准注意力+49 gated delta-net），vocab=248320 |
| 素材 | bis_142/143 永久丢失（golden 三硬门替代）；t285.txt(34,490B)/req_t285.json(7,695tok)/longprompt.txt(33,125B) 在 D:\temp；**D:\temp 易失**，golden.ps1/mtp_test.ps1/apply_nc.py **仍未入库（v4 遗留，勿再拖）** |
| 构建 | llama.cpp\build\bin\Release\；**当前二进制=含 3d19fc4（GRAPH_FORCE）+32b9763（AR_P2P）的构建**。**重建前必 taskkill+ping 6**（LNK1104=DLL 写锁教训） |

**标准命令三档（v5 修订：GRAPH_FORCE=1 为日常默认；数字为图前旧口径，图后重定标见 §3.2）**：

贪心/精确档（日常默认；图前 37.7~38.7 t/s，**图后预期 ~42-44 待重定标**）：
```bash
set GGML_CUDA_GRAPH_FORCE=1
llama-server.exe --model I:\AiModels\001\002\Qwen3.8-27B-MTP-Q8_0.gguf ^
 --ctx-size 262144 --n-gpu-layers 999 -sm tensor --tensor-split 16,16,16,16 ^
 --batch-size 4096 --ubatch-size 1024 --threads 20 --parallel 1 ^
 --temp 0 --fit off -fa on --cache-type-k f16 --cache-type-v f16 --no-mmap ^
 --spec-type draft-mtp --spec-draft-n-max 3
```

创作档（UD+creative；图前 29.3~29.5，图后未测；**勿加 spec**——创作 MTP 双模型实证为负）：
```bash
set GGML_CUDA_GRAPH_FORCE=1
llama-server.exe --model G:\AiModels\001\002\Qwen3.8-27B-UD-Q8_K_XL.gguf ^
 --ctx-size 262144 --n-gpu-layers 999 -sm tensor --tensor-split 16,16,16,16 ^
 --batch-size 4096 --ubatch-size 1024 --threads 20 --parallel 1 ^
 --temp 0.8 --top-p 0.95 --top-k 40 --min-p 0.05 --repeat-penalty 1.05 --repeat-last-n 256 ^
 --dry-multiplier 0.8 --dry-base 1.75 --dry-allowed-length 2 --presence-penalty 0.3 ^
 --fit off -fa on --cache-type-k f16 --cache-type-v f16 --no-mmap --jinja
```

省电档（3 卡同根 0 跨 UPI 跳；ctx≤131k；图前 37.00，图后待重定标）：
```bash
set CUDA_VISIBLE_DEVICES=1,2,3
set GGML_CUDA_GRAPH_FORCE=1
llama-server.exe --model I:\AiModels\001\002\Qwen3.8-27B-MTP-Q8_0.gguf ^
 --ctx-size 131072 --n-gpu-layers 999 -sm tensor --tensor-split 16,16,16 ^
 --batch-size 4096 --ubatch-size 1024 --threads 20 --parallel 1 ^
 --temp 0 --fit off -fa on --cache-type-k f16 --cache-type-v f16 --no-mmap ^
 --spec-type draft-mtp --spec-draft-n-max 3
```

**MoE 日常档（v5 新增，R39/R41 定标）**：tensor split（勿用 layer——图后 tensor 61.5 > layer 52.5~58.6，
且 layer 的 pp 也吃亏）；ubatch 1024 / batch 4096 / parallel 1 / --jinja；server 实测 61.5 t/s。

### 1.2 P100 硬件特殊性（出发点，不变）

- GP100=唯一"全速 fp16 且无 __dp4a"的 Pascal；fp16 half2 **15.8 TOP/s = 4.0× 模拟 int8**（3.95）；fp32 8.68。
- **解码瓶颈=指令发射非带宽**（每权重 9.25 SASS、发射 76-99%、带宽只用 27%）⇒ 降指令数≈1:1 变加速。
- HBM2 实测 607 GB/s；250W 墙 **~60s 热节流**（A/B 必冷机 ping -n 121）；2 拷贝引擎；无 NVLink/Tensor Core；PCIe 3.0。
- **跨 UPI 跳 ≈3~4% tg/跳**：无 MTP 时第 4 卡净收益 +7.4%，MTP 时仅 +2.0%。CVD=1,2,3 时环全在 CPU2 同根。
- **跨 socket P2P=硬件拒绝**（can=0），同 socket 6/6 对全通（probe 实测）——32b9763 的 P2P staging 在本机休眠。

### 1.3 qr0n 原理速览（+v5 图机理）

1. 解码：量化 matvec 改 fp16 half2 FMA（0007/0008）⇒ 8B tg 2.03x。0007 覆盖=单列 Q3/Q4/Q5/Q6_K/IQ4_XS/IQ4_NL/Q8_0 + 多列 Q4_K/Q5_K/IQ4_XS(2..8列) + Q8_0/IQ4_NL split-K。
2. 跨卡：0003/0004 放开 Pascal AllReduce+双流重叠（本机 4 卡 2.3x/+39%）。
3. 预填充：0010 cuBLAS-GEMM FA+GQA tile（fp32 默认=NaN 修复）。
4. 内核间隙：0009 delta-net 小内核折叠（+9.1% 逐位一致）。
5. **（v5）CUDA graph 解锁（3d19fc4）**：上游 graph 管线（流捕获/uid 图缓存/两次暖启动/cudaGraphExecUpdate）被
   cc<Volta 一道检查挡死；三行编辑+env 解锁。机理=**收编宿主 API 节拍**：~22.5k 次内核启动调用收拢为 3612 次
   图重放，内核间 host 间隙 1.8-3.1µs→1.3µs，四设备起始瀑布 0/14.8/34.3/67.3→0/10.8/19.3/40.9µs；
   **AR 入队路径仍在宿主**（~22µs/设备/轮，经 comm 接口发出，捕获区不含它）——这是下一个主攻的靶子（§3.1）。

### 1.4 已取得成果（v4 全部有效 + v5 追加 P12 战役）

- v3/v4 存量：NaN 毒化修复（fp32 默认，24/24 全净）；四卡 AllReduce 2.3x/+39%；MTP 定标（贪心 +10~13%，
  acceptance 0.547/0.565-0.571，创作档负）；f 模型方法论（f_Q8≈2.03）；nc 多列内核否决（-29~36%，机理入库）；
  golden v2 对拍协议；issue #4 已答复。
- **v5 追加（P12 战役，全部落库 README 专节）**：
  - **GGML_CUDA_GRAPH_FORCE（3d19fc4，ggml-cuda.cu +3/−1）**：缺省/0/空=旧行为（已验证逐字节一致）；
    非 0=跳过 Volta 门禁，graph 管线在 P100 运行。AR 经 comm 接口留在图外。
  - **cli 战果（temp0/-p Hello/-st）**：27B-MTP 34.13→39.30±0.15（+15.2%，MTP n3）；27B-UD 32.5→37.4、
    n2048 32.4→37.9（+15~17%）；A3B 33.6→78.4/83.8（**+133~149%**）。
  - **server 战果（同一条 378-token 提示词、temp0.8、全采样链、tensor）**：27B-UD 21.9/22.9→32.2/32.5
    （1.42-1.47×，两轮复现）；A3B 23.2→61.5（**2.64×**）。server 比值优于 cli：无图臂的多余 launch 落在
    更贵宿主路径被重罚；绝对值吃操作点折扣（固定宿主地板≈模型无关：采样链+流式+AR 入队）。
  - **正确性三重证据**：temp0 双臂 n128 MD5×4（27B-MTP）+ **n2048 全程 MD5 相等**（27B-UD=ECA65C64…、
    A3B=3C95B9ED…）——图重放与非图路径 2K token 位级等价，腐坏假说枪毙。
  - **图销毁税（2×2 判别坐实）**：图开退出 40-55s（4 卡缓存图工单逐张同步销毁×pre-Volta 驱动单价），
    图关<1s，与模型无关；纯退出环节。**日常关服=taskkill /f /im llama-server.exe**（无持久状态，安全）。
  - **结构结论**：无图解码速度与模型无关（A3B 23.2≈27B 22.9，第六证）；layer/tensor 随图翻转
    （无图 layer 50.3>tensor 23.2 免 AR 税；图后 tensor 61.5>layer 52.5-58.6）。
  - **emoji 吸引子案**：temp0+ignore-eos+裸 Hello 贪心复读，双臂 MD5 逐字节同=模型行为非腐坏；
    判别器=findstr+MD5 双臂；日常使用（正常温度+EOS+有内容 prompt）不触发。
  - **MTP 正交**：图收益不依赖 MTP、不动盈亏线；低接受率负载关 MTP 照拿图收益。
  - **batch/ubatch 结论**：不影响 tg（decode 每步≤parallel 个 token；27B ubatch 2048 vs 4096 实测同）；
    仅 prompt>1×ubatch 时 prefill 受益且递减；显存随 ubatch 线性（27B 4096+262k→14/16GB/卡）。

### 1.5 基线数字（v5 重写；口径纪律=绝对数字跨口径不可比，只有同口径成对差值可比）

**v5 新基线（GRAPH_FORCE=1 时代，本轮实测）**：

| 口径 | 配置 | 图关 | 图开 | 证据 |
|---|---|---|---|---|
| cli 微基准（temp0、-p Hello、-st） | 27B-MTP / MTP n3 | 34.13（7轮 33.8-35.6） | **39.30±0.15** | n128 MD5×4 |
| cli | 27B-UD / 无MTP | 32.5（n2048 32.4） | **37.4**（n2048 37.9） | n128+n2048 MD5 |
| cli | A3B / 无MTP | 33.6 | **78.4 / 83.8(n2048)** | n128+n2048 MD5 |
| server 真实请求（378tok、全采样链、tensor） | 27B-UD | 21.9 / 22.9 | **32.2 / 32.5** | 两轮成对 |
| server | A3B | 23.2 | **61.5** | 单发成对 |
| server 对照（layer split） | A3B | 50.26 | 52.5-58.6 | 勿用于日常 |

**v4 旧基线（graph 关闭时代，口径各异——mtp_test.ps1/golden.ps1 vs webui 全采样链差异极大，勿与新表直比）**：
贪心 Q8_0+MTP 37.73~38.65｜贪心 UD 32.2~32.6｜创作 UD 29.3~29.5｜省电 3 卡 37.00｜synth a=4 f_Q8≈2.03。
**图后三档重定标 = §3.2 首项**（预期贪心档 ~42-44、省电 ~42、创作待测；A3B server 61.5 已是新锚点）。

pp：图前 7,695tok 老口径 315.2（graph 不动 prefill）；系统性 pp 重测仍遗留（P18）。

### 1.6 研究意图（不变）

单用户单流 pp/tg 最大化；延续 qr0n 路线（fp16、压指令、压通信、压间隙、**压宿主节拍**）；
每改动独立构建+验证门+冷机 A/B，成果以 README/patch/commit 落账。**并发聚合不是目标。**

---

## 2. 项目结构与补丁

### 2.1 目录与工具

patches\ 0001..0012*.patch；tools\（verify-source.sh / ggufinfo.py / **建议新增 golden.ps1、mtp_test.ps1、
apply_nc.py.archived——仍未入库，D:\temp 易失，v5 再次催办**）；bench\sweep.cu；data\q4k_one.sass；
README.md / README.zh-CN.md（权威）；HANDOFF.md 本文件（**v5 建议入库**，见文末命令）。
D:\temp 现存：golden.ps1(v2)、mtp_test.ps1、apply_nc.py、ttype30.py、req_t285.json、t285.txt、longprompt.txt、
srv*.log、golden_*.txt、bin_old\、cli*.txt、trace*csv。

```cmd
copy /y D:\temp\golden.ps1 D:\p100-llama-cpp\tools\
copy /y D:\temp\mtp_test.ps1 D:\p100-llama-cpp\tools\
copy /y D:\temp\apply_nc.py D:\p100-llama-cpp\tools\apply_nc.py.archived
git -C D:\p100-llama-cpp add tools/golden.ps1 tools/mtp_test.ps1 tools/apply_nc.py.archived
git -C D:\p100-llama-cpp commit -m "tools: add golden/mtp_test scripts and archived nc-kernel patcher"
git -C D:\p100-llama-cpp push
```

### 2.2 补丁/提交分工表（★=已应用并推送；☆=参考未应用；⊕=已开发否决回滚）

★ 0001 免重算 q8_1 块和(+4%)｜★ 0002 GP100 MMVQ 参数表(+33% 合计)｜★ 0003 放开 AllReduce｜
★ 0004 copy-engine 双流｜★ 0005 向量化 f32↔f16｜★ 0006 AllReduce N 设备(2.3x/+39%)｜
★ 0007 fp16 MMVQ(8B 2.03x)｜★ 0008 split-K｜★ 0009 delta-net 折叠(+9.1%)｜
★ 0010 cuBLAS-GEMM FA（fp32 默认=NaN 修复，FA_GEMM_PREC=16 逃生门）｜
☆ 0011 并发 agent｜☆ 0012 GQA tile GP100 限定｜⊕ 0013(未入库) Q8_0 多列 verify（-29~36%，全文存 apply_nc.py）｜
**★ 32b9763 AR P2P staging（allreduce.cu +63/−2；GGML_CUDA_AR_P2P 默认开，任一对被拒整体回退 copy staging；
本机休眠=输出逐字节一致热路径零扰动；UPI 病态机器逃生门 AR_P2P=0）**｜
**★ 3d19fc4 GRAPH_FORCE（ggml-cuda.cu +3/−1；本轮主角）**｜★ 45e9e74 README 终版（153+/81−）。

**已知负结果（勿盲目重试）**：
- ~~CUDA graphs −1.4%~~ **已被本轮推翻为"双卡机器特例"**：同一套 graph 代码在四卡机大赢 +15~149%——
  规律=启动次数削减的收益∝它移除的宿主税；双卡税小故负，四卡税大故正（README"落选段"已改写为两面证据）。
- 多列 fp16 内核（Q6_K/Q8_0/IQ4_NL）：非 8B 对齐块须 shared staging，摊不回解包往返；
  **规律：多列 fp16 仅对 ldg 型（8B 对齐直读 Q4_K/Q5_K/IQ4_XS）成立**。
- 创作档 MTP（双模型实证）；GGML_CUDA_P2P 跨 UPI 10.7x 倒退；-ctk q8_0 在 sm_60 倒退；MMVQ 融合 −2.1%。
- **graphs reused 计数器≠图开关证据**（llama 侧计算图计数，图关也约每 token 加一；R37 认账）——
  判图开关只看同口径成对速度差或 nsys cudaGraphLaunch 计数。

### 2.3 操作纪律（v4 全部有效 + v5 graph 时代追加）

- **重建前必 taskkill /f /im llama-server.exe + ping -n 6**（LNK1104 教训）；LLAMA_UI_GZIP 警告无害。
- **日常关服=taskkill /f /im llama-server.exe**（多实例先 tasklist|findstr 再 /pid 点杀；请求进行中勿杀）；
  图开时 Ctrl+C 退出 40-55s 属正常（图销毁税），勿误判为卡死。
- **env 纪律**：set 后必清+无等号回显验证（set GGML_CUDA_GRAPH_FORCE）；新配置新窗口；
  env 七件套：GRAPH_FORCE / AR_P2P / ALLREDUCE / P2P / NUMA / FORCE_CUBLAS / FA_GEMM_PREC。
- **PS5.1 三坑**：①单元素 JSON 数组折叠标量，取元素用 @($x)[0]；②thinking 模型 content 为空
  （token 在 reasoning_content），请求体加 chat_template_kwargs=@{ enable_thinking=$false } 并拼接
  reasoning_content（golden.ps1 v2 已内置）；③交付脚本必测目标机特性。
- **正确性验证门**：golden 三硬门（temp0+enable_thinking=false+固定英文提示+256tok，G1/G3/U1 三配置
  逐位一致；限不碰 attention/KV 的改动）；**v5 增补 M1 MD5 双臂模板**（cli temp0 双臂全文 MD5，n128 快筛/
  n2048 强证据，战役内四次复用）；触碰 attention/KV 仍必须触发阶梯。
- 冷机=ping -n 121 127.0.0.1 >nul；单发数字注明冷/热；mtp_test 两发取二发。
- 工具用法：golden.ps1 -Tag X（打印 md5/prompt_n/pred_n/tg）；mtp_test.ps1 -Tag X [-Mode creative]；findstr 不跨行。
- 1-token prompt 的 prompt 速度=固定开销噪声不可读；server 的 slot 首请求偏慢属暖机。

---

## 3. 优化路径清单（v5 按实测重排）

### 3.0 已结项（勿再投入）

P01 TCC｜**P02 MTP**（贪心落地/创作关/A3B 尾巴选做）｜P05 配比盘点｜**P08 fp16 MMVQ**（单列已生效、
多列否决）｜P11 并发（出局）｜P06 布局主体（跨 UPI 定量+省电档落地）｜
**P12 CUDA graph 解锁（v5 收官：三模型双口径+MD5 三重证据+README 落账 45e9e74）**。

### 3.1 推荐主攻：AR 入队路径收编（"AR 图内化"）

- **立项依据（已有数据）**：nsys 图内实测 AR 入队残留 ~22µs/设备/轮（4 卡≈88µs/轮）=graph 解锁后
  唯一剩下的大块宿主工作；"宿主税=地板"已六次兑现，收编它即抬天花板。
- **预期**：27B cli 图内 39.30 → **~45-47（+15~20%）**（按图前 gap 结构推算，须诊断复核）；
  A3B 轮更快残留占比待实测（初估 <5%）另计；server 口径同步受益（27B 32.2→~37-38）。
- **方案三件套（v4 规划延续）**：①counter-token——到达标志改设备侧自旋计数（chunked kernel 本就是
  设备侧自旋，理论上可捕获）；②allreduce.cu:441 守卫；③comm 下沉——把
  ggml_backend_comm_allreduce_tensor 的宿主调用下沉进图。
- **技术风险**：CUDA capture 对跨设备同步原语的兼容性——graph 管线自带节点兼容检查，拒绝则自动回退
  逐 kernel（无害无收益）；host pinned flag 的 threadfence_system 语义在图内是否保持；MTP verify 批
  同样付 AR（成功则贪心+MTP 双抬）。
- **前置诊断（0.2 协议示范）**：第一发 nsys 抓 27B 图内 run，量化 AR 入队占比、拆延迟 vs 带宽，
  确认 22µs/设备/轮在新基线仍成立→再锁最终预期→交用户确认→实施。
- **验证门**：golden 三硬门（不碰 attention/KV，适用）+ 冷机 A/B（图开双臂）+ nsys 复测 AR 入队归零。

### 3.2 廉价批（一个下午全带过；**首项必做**）

**三档+MoE 重定标**（GRAPH_FORCE=1 下重跑 golden/mtp_test 四档位，建立 v5 基线账本，含创作档图后首测）
｜P03 ubatch 512/2048 扫描（t285；注意 batch/ubatch 结论——tg 不动，只影响长 prompt pp）｜
P04 FA_GEMM=0 tile vs GEMM @8k 再裁决｜P07 时钟卫生｜P06 剩余（bench r=3 复核 1+3 vs 2+2、CVD 变体）｜
P10 AR bf16（AR_BF16_THRESHOLD=1+毒化阶梯）｜P18 longprompt pp 补测（素材已备）。

### 3.3 中期

**P17 采样栈优化**（创作档唯一大杠杆：图前采样栈≈5.6ms/tok；图后解码核变快采样栈占比更高——
先画像再动手）｜P14 A3B 深挖（基线已立：cli 83.8/server 61.5；勿 -ncmoe）｜
P16 标准注意力 0009 式融合（+3~8%）｜P09 cublasLt 组合（+1~3%）。

### 3.4 远期

P15 自研 fp16 GEMM｜P13 P2P（本机预期负，代码已入库休眠）｜ldg 型 Q8_0-nc（低优先级）。

### 3.5 下窗口建议打法

① **0.2 协议开局**：通读→选主攻（建议 §3.1）→预期%→用户确认→诊断模式；
② §3.2 廉价批/重定标带过；③ 每改动独立构建+验证门+冷机 A/B，落账 commit/README。

---

## 4. 遗留事项（v5 更新）

- **工具入库（§2.1 六条命令）仍未做——最高优先级**（nc 内核全文仅存 D:\temp\apply_nc.py，易失）。
- **HANDOFF.md 本身入库**（v5 新增建议，见文末）。
- F1"真免 env 终验"：GRAPH_FORCE 缺省行为已验证（smoke+G0 臂），其余 env 的零 env 终验仍可顺手做。
- issue #4 等 qr0n 验证；0013 形式 PR 未承诺。
- pp 系统性基线在 262k 新配置下未建（并入 P18）；插槽 1+3 vs 2+2 待 bench r=3 复核（P06）。
- A3B server 无图臂成对比值已补齐（R41）；"no paired ratio"句 README 已更新为实数。

---

## 5. P12 战役档案（v5 新增；细节以 README 专节与收卷摘要为准）

### 5.1 commit 链（GitHub key-sh/p100-gp100-fp32 tip=45e9e74）
7bc6d4e（ggumeta.py）→ 32b9763（P2P staging 休眠）→ 3d19fc4（GRAPH_FORCE 解锁）→ 45e9e74（README 终版 153+/81−）。

### 5.2 nsys/trace 档案
cli_ar1(66.2/21.8,LaunchKernel81832)/ar2(70.9/20.9)/ar3(66.5/22.1,offset 0/14.8/34.3/67.3)/
ar4(68.9/22.4)/map(-ts28,26.4)/**graph(54.5/22.4,GraphLaunch3612,LaunchKernel59352,Δlaunch=−22480,
offset 0/10.8/19.3/40.9,med555)**；trace1/3/4/M/G csv。图前轮 651µs→图后 570µs
（按 launch 数预测 −88µs、实测 −81µs，误差 ~10%——最可迁移数字）。

### 5.3 方法论（v5 沉淀）
预注册判读树（先写预期带后测）｜守恒律｜MD5/temp0 双臂腐坏探测（M1 模板）｜关键路径先验｜
**速度差=图开关唯一 oracle（计数器作废）**｜退出秒数 2×2 判别器｜1-token prompt=固定开销噪声｜
server graphs reused≠重放证据。

### 5.4 认账封卷 18 项（教训索引，新对话避免重蹈）
①6144 实例计数错 ②B/A 臂反号 ③pool 主带落空 ④V3 次数 ⑤R15 宿主税首述不准 ⑥R18 两笔 ⑦摘要遗漏
（→立固定末尾纪律）⑧api 半盲 ⑨R23 $_/$r ⑩R24 两翻案 ⑪R25 签名错置 ⑫R26 C2 相位 ⑬R33 A3B 幅度失准
（方向对量级错，跨模型外推须重测）⑭graphs-reused 计数器误读 ⑮server 阈值 ≥70 未命中（折扣低估 −14%）
⑯R35 条件预注存目 ⑰**双仓库模型误判**（多轮"父+子仓库"表述，实为单仓库；显式 push 第二句=空操作）
⑱**未验证即断言**（凭口述断言 commit 在库未索取 log——**纪律：任何 git/文件状态断言必须基于当轮真实输出**）。

### 5.5 日常指引速查
setx GGML_CUDA_GRAPH_FORCE 1（异常先 =0 复验）；27B ubatch 4096/batch 8192（2GB 余量紧张 OOM 退 2048）；
A3B ubatch 1024/batch 4096 可试 2048；关服 taskkill /f /im；正确性抽验 M1 模板。

<!-- ===== HANDOFF.md v5 结束 ===== -->
