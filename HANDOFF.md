<!-- ===== D:\p100-llama-cpp\HANDOFF.md（v8，2026-10-18，key-sh）===== -->

> 用途：新聊天窗口起点。版本演进：
> v5：P12 CUDA graph 解锁战役收官（GGML_CUDA_GRAPH_FORCE 落地，三模型双口径战果+三重位级正确性证据
> 入库 commit 3d19fc4/32b9763/45e9e74 并推送 GitHub）。
> v6：P19"AR 图内化"战役判死收官（P19-A 回档/P19-B+P20 双死刑/Phase C 立项不启动，残值 0.29%/tok
> 可忽略）；主场景锁定=文学创作，路线图按创作口径重估；外部资料全面核查入库；代码成果=6fb569d。
> v7：PCIe 带宽认知纠偏（§1.7 专节：AR 每步发生且占 TG ~15-20%，但归因=固定延迟而非带宽，
> 带宽仅占 0.1-0.3%）；诊断 B 实测=sm_60 FP16 carveout 未免疫实锤（§3.8，修复战役待启动）。
> v8：issue #25593 收窄修法战役收官（common.cuh:311 单行 carveout；KLD 终审全分位 977×~9.1×10³、
> argmax 翻转 1.94%→0%、decode 0% 噪声级）；诊断 A 证伪 P17 一期（−1.29 ms/tok，主攻位空缺）；
> R22 悬案闭合（40.8±1.1，44~47 判伪）；tools ghost 闭合（98cbe9b 早已入库）；
> KLD 面板沉淀为常设数值闸门；代码成果=5216f92/de26e65/2ce560c/0133a37。
> 【v8.1】wave1 host 三件套战役档案=§7：+5.46% 入库、golden 三硬门基线、方法论与认账 43-54、wave2 预注册（§7.5 状态已被 v8.2 更新）。
> 【v8.2】#22 decode slot pool 战役档案=§8：移植→验证拦截→取证→判死不可 ship（上游 #29466 互链，代码存档 archive/22-decode-slotpool）；认账 55-81；§7.5 状态行已更新。
> 权威数据源：根目录 README.md / README.zh-CN.md 专节；README 与本 HANDOFF 冲突时以 README 为准。
> v5/v6/v7 全部内容保留未删减；【v8】为修订与勘误标注，与 v7 原文冲突处以【v8】为准。

## v5→v6→v7→v8 变更索引（新窗口快速定位）

【v6】§0.2 协议第 5 条｜§1.4/1.5/1.6 增补｜§2.2/2.3 增补｜§3.0 判死项｜§3.6 创作重估总表｜
§3.7 外部核查档案｜§3.8 诊断 B｜§6 P19 档案｜§4 遗留追加｜§5.4 认账⑲
【v7】§0.1 避坑④⑤⑥｜§0.2 第 5 条｜§1.7 PCIe 带宽认知专节（必读）｜§3.1 主攻修订｜
§3.6 带宽类项预期修订｜§3.8 诊断 B 实测结果｜§5.4 认账⑳
【v8】§0.1 tip/二进制身份更新｜§1.1 仓库/素材行｜§1.4 增补｜§1.5 R22 闭合｜§2.1 tools ghost 闭合｜ §2.2 补丁表增补｜§3.0 增 #25593/P17 结项｜§3.1 主攻重排（P16 上位）｜§3.3 P17 改判｜§3.5 打法更新｜ §3.6 表修订｜§3.7 #25593 行更新｜§3.8 收官档案（含两处勘误）｜§4 遗留大扫除｜§5.1 commit 链｜ §5.4 认账㉒~㉝
【v8.1】§7 wave1 战役档案（判决/数字/三门/方法论/认账 43-54）｜§7.5 wave2 预注册
【v8.2】§7.5 状态更新（#22 已判死）｜§8 #22 战役档案（8.1 判决/8.2 取证/8.3 保全与重启/8.4 基线勘误与门套/8.5 认账 55-81）
§2.2 补丁表增补｜§3.0 增 #25593/P17 结项｜§3.1 主攻重排（P16 上位）｜§3.3 P17 改判｜§3.5 打法更新｜
§3.6 表修订｜§3.7 #25593 行更新｜§3.8 收官档案（含两处勘误）｜§4 遗留大扫除｜§5.1 commit 链｜
§5.4 认账㉒~㉝

---

## 0. 新对话工作协议（必读，置于最前）

### 0.1 项目架构速查（v4 缺失导致的重复获取/误判，一次性写清）

- **单仓库结构（R44 实锤，勿再误判）**：D:\p100-llama-cpp 是**一个** git 仓库；
  llama.cpp\ 是其中普通子目录（内含上游源码+patches+build），**不是嵌套仓库**——在 llama.cpp\ 下执行 git
  命令会向上命中父仓库，log 哈希与父目录完全一致；push 永远只需一句 git -C D:\p100-llama-cpp push
- **远端**：myfork = git@github.com:key-sh/p100-llama-cpp.git（本人仓库，日常 push 目标）；
  origin = https://github.com/qr0n/p100-llama-cpp.git（上游作者，**永远不要 push origin**，无权限）。
- **获取现状的标准命令**（新对话开始先跑这一组，勿凭记忆断言）：

```cmd
git -C D:\p100-llama-cpp log --oneline -5
git -C D:\p100-llama-cpp status --short
git -C D:\p100-llama-cpp remote -v
git -C D:\p100-llama-cpp branch --show-current
dir D:\p100-llama-cpp\llama.cpp\build\bin\Release\llama-server.exe D:\p100-llama-cpp\README.md
```

  预期：tip≥0133a37【v8】（含 5216f92 #25593 修法/de26e65 KLD 语料/2ce560c README 专节/0133a37 本文档）；
  树干净；分支 p100-gp100-fp32；二进制存在。
- **权威数据源**：根目录 README.md / README.zh-CN.md 的《This branch (key-sh): GGML_CUDA_GRAPH_FORCE》
  专节——全部速度数字、机理数字、emoji 案、MTP 正交、batch/ubatch 结论都在；
  **README 与本 HANDOFF 冲突时以 README 为准**（随 commit 落库更及时）；
  判死/结项判定以本 v8 §3.0/§3.6 关闭清单为准（README 更新可能滞后一轮）。
- **避坑三条（v5）**：①勿凭记忆断言文件状态（ggufinfo.py"损坏"误判、R43 未验证即断言 commit 在库，
  均已成认账）——先跑命令看真实输出；②llama.cpp\build 是构建产物目录，bin_old\ 等备份在 D:\temp（易失）；
  ③【v8 更新】二进制当前=含 3d19fc4 图解锁与 5216f92 #25593 修法的构建（DLL 时间戳 2026-10-17 0:42:33），
  任何 env 未设时行为=旧版逐字节一致（已验证）。
- 【v7】**避坑追加**：④**P21 口径漂移**——每次测速前必验 set GGML_CUDA 回显（应仅 GRAPH_FORCE，
  不得出现 AR_P2P/AR_ASYNC）+ ping -n 121 冷却（R22 探针1 40.5 出带即此因，已两次踩坑）；
  ⑤**版本宏不可作身份判据**；⑥**R13-②测量功效**——所有百分比增量必须独立测量，不可叠加推算。

### 0.2 每轮单主攻协议

1. 通读本 HANDOFF 全文（尤其 §3 路线图与战役档案）后，分析确定**一个**主攻方向，写明：
   立项依据（引用已有数据）、预期提升百分比（须给出推算过程）、验证门（MD5/golden/冷机 A/B），
   **交用户确认**。不得未经确认直接动手。
2. 用户确认后立即进入诊断模式：AI 直接给诊断/测试命令（用户只执行并贴回完整输出），
   AI 解读研判后给下一轮诊断命令；**不要让用户判断结果、写命令或写脚本**。
3. 全部疑问解决后，才提出具体解决方案并实施（独立构建+验证门+冷机 A/B+commit 落账）。
4. 预注册纪律：给命令时同时给"预期结果带"，实测落带/落带外分别意味着什么，先写后测；
   落带外优先怀疑预期与口径，再怀疑系统。
5. 【v7】**认知争议处理**：若用户对某项机理判断与 HANDOFF 实测数据冲突，先用数据推演+
   已有 A/B 证据澄清（如 §1.7），确认后再立项；不得为迎合用户推翻实测结论，也不得无视用户合理质疑。

### 0.3 摘要纪律（上下文受限，强制）

- **每轮对话结束时**，AI 在回复末尾输出累积摘要（HTML 注释包裹），内容=上轮摘要全量+本轮增量；
  认账/预注册/结论**只增不删**。
- 用户在**下一轮第一条消息**把上一轮摘要全文贴回。
- 战役收官时，AI 另产出 Markdown 收卷摘要 + 更新本 HANDOFF。

---

## 1. 环境与背景

### 1.1 软硬件环境

| 项 | 值 |
|---|---|
| GPU | **4x Tesla P100-PCIE-16GB**，sm_60/GP100，全 TCC |
| 布局 | 插槽 2\|4\|6\|5 → GPU0-3；**GPU0(02:)=CPU1 独居，GPU1-3(81/82/83:)=CPU2 同根复合体**（1+3 布局）；**实测每跨 UPI 跳 ≈3~4% tg** |
| 主机 | X99，双路 E5-2699v3（36C/72T），64GB；**构建 -j 36~48**（nvcc 单文件为主，再大无益）【v6】构建 --parallel 36 |
| CUDA/驱动 | 12.8 / 573.76（**勿升 13**）；nvidia-smi topo -m 不可用，用总线号判 socket |
| 仓库 | D:\p100-llama-cpp，**单仓库**（见 0.1），分支 p100-gp100-fp32，remote myfork；【v8】**tip≥0133a37**（含 32b9763 P2P staging、3d19fc4 graph unlock、45e9e74 README 终版、6fb569d P2P 默认 0 修复、5216f92 #25593 修法、de26e65 KLD 语料、2ce560c README 专节、0133a37 本文档）；树干净 |
| 模型 | **速度档**：I:\AiModels\001\002\Qwen3.8-27B-MTP-Q8_0.gguf（29G，纯 Q8_0+F32，含 nextn）；**质量主力**：G:\AiModels\001\002\Qwen3.8-27B-UD-Q8_K_XL.gguf（31.5G，90.6% Q8_0+9.4% BF16）；**MoE**：G:\AiModels\001\002\Qwen3.6-35B-A3B-UD-Q6_K_XL.gguf（图解锁最大受益者 2.5x，tensor+图 server 61.5 t/s）。27B=hybrid 66 层（17 标准注意力+49 gated delta-net），vocab=248320，head_dim=128 |
| 素材 | bis_142/143 永久丢失（golden 三硬门替代）；t285.txt(34,490B)/req_t285.json(7,695tok)/longprompt.txt(33,125B) 在 D:\temp；**D:\temp 易失**；【v8】golden.ps1/mtp_test.ps1/apply_nc.py.archived **已入库（98cbe9b，ghost 考证闭合）** |
| 构建 | llama.cpp\build\bin\Release\；**重建前必 taskkill+ping 6**（LNK1104=DLL 写锁教训） |

**标准命令三档（GRAPH_FORCE=1 为日常默认；数字为图前旧口径，图后重定标见 §3.2）**：

贪心/精确档（日常默认；图前 37.7~38.7 t/s，图后 ~42-47 区间待定标，R22 复测悬案待闭）：

```bash
set GGML_CUDA_GRAPH_FORCE=1
llama-server.exe --model I:\AiModels\001\002\Qwen3.8-27B-MTP-Q8_0.gguf ^
  --ctx-size 262144 --n-gpu-layers 999 -sm tensor --tensor-split 16,16,16,16 ^
  --batch-size 4096 --ubatch-size 1024 --threads 20 --parallel 1 ^
  --temp 0 --fit off -fa on --cache-type-k f16 --cache-type-v f16 --no-mmap ^
  --spec-type draft-mtp --spec-draft-n-max 3
```

创作档（【v7】**主场景**；图前 29.3~29.5，图后 v5 锚点 32.2/32.5；**勿加 spec**——创作 MTP 双模型实证为负，p-min 重审判未做）：

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

**MoE 日常档（R39/R41 定标）**：tensor split（勿用 layer——图后 tensor 61.5 > layer 52.5~58.6，
且 layer 的 pp 也吃亏）；ubatch 1024 / batch 4096 / parallel 1 / --jinja；server 实测 61.5 t/s。

【v6】**每次测速前检查（P21 纪律）**：set GGML_CUDA 回显（应仅 GRAPH_FORCE）+ ping -n 121 冷却；
新配置新窗口。

### 1.2 P100 硬件特殊性（出发点，不变）

- GP100=唯一"全速 fp16 且无 __dp4a"的 Pascal；fp16 half2 **15.8 TOP/s = 4.0× 模拟 int8**（3.95）；fp32 8.68。
- **解码瓶颈=指令发射非带宽**（每权重 9.25 SASS、发射 76-99%、带宽只用 27%）⇒ 降指令数≈1:1 变加速。
- HBM2 实测 607 GB/s；250W 墙 **~60s 热节流**（A/B 必冷机 ping -n 121）；2 拷贝引擎；无 NVLink/Tensor Core；PCIe 3.0。
- **跨 UPI 跳 ≈3~4% tg/跳**：无 MTP 时第 4 卡净收益 +7.4%，MTP 时仅 +2.0%。CVD=1,2,3 时环全在 CPU2 同根。
- **跨 socket P2P=硬件拒绝**（can=0），同 socket 6/6 对全通（probe 实测）——32b9763 的 P2P staging 在本机休眠。

### 1.3 qr0n 原理速览（+v5 图机理）

1. 解码：量化 matvec 改 fp16 half2 FMA（0007/0008）⇒ 8B tg 2.03x。0007 覆盖=单列 Q3/Q4/Q5/Q6_K/
   IQ4_XS/IQ4_NL/Q8_0 + 多列 Q4_K/Q5_K/IQ4_XS(2..8列) + Q8_0/IQ4_NL split-K。
2. 跨卡：0003/0004 放开 Pascal AllReduce+双流重叠（本机 4 卡 2.3x/+39%）。
3. 预填充：0010 cuBLAS-GEMM FA+GQA tile（fp32 默认=NaN 修复）。【v7】注意：0010 的 fp32 默认
   **只覆盖 FA-GEMM 一条路**，FFN/projection GEMM 的 compute type 受 common.cuh 门禁控制（见 §3.8）。
4. 内核间隙：0009 delta-net 小内核折叠（+9.1% 逐位一致）。
5. （v5）CUDA graph 解锁（3d19fc4）：上游 graph 管线被 cc<Volta 一道检查挡死；三行编辑+env 解锁。
   机理=**收编宿主 API 节拍**：~22.5k 次内核启动收拢为 3612 次图重放，内核间 host 间隙 1.8-3.1µs→1.3µs，
   四设备起始瀑布 0/14.8/34.3/67.3→0/10.8/19.3/40.9µs；
   AR 入队路径仍在宿主（~22µs/设备/轮，经 comm 接口发出，捕获区不含它）——P19 曾主攻此靶，已判死（§6）。

### 1.4 已取得成果（v4 全部有效 + v5 P12 + v6 P19 + v7/v8）

- v3/v4 存量：NaN 毒化修复（fp32 默认，24/24 全净）；四卡 AllReduce 2.3x/+39%；
  MTP 定标（贪心 +10~13%，acceptance 0.547/0.565-0.571，创作档负）；f 模型方法论（f_Q8≈2.03）；
  nc 多列内核否决（-29~36%）；golden v2 对拍协议；issue #4 已答复。
- v5 P12 战役：GGML_CUDA_GRAPH_FORCE（3d19fc4，ggml-cuda.cu +3/−1）；cli 战果 27B-MTP 34.13→39.30
  （+15.2%）、27B-UD +15~17%、A3B +133~149%；server 战果 27B-UD 1.42-1.47×、A3B 2.64×；
  正确性三重证据（MD5 三重）；图销毁税（退出 40-55s，taskkill 规避）；MTP 正交；batch/ubatch 结论。
- 【v6】P19 战役：AR 图内化判死（详见 §6）；本窗口最终代码成果=**6fb569d**（P2P staging 默认 0，
  +8/−1，fork 独有文件，qwen3.9 移植分钟级）。
- 【v7→v8】诊断 B → **已修复收官**：#25593 收窄修法落地（common.cuh:311 单行 carveout，5216f92），
  KLD 终审全分位 977×~9.1×10³、argmax 翻转清零、decode 0% 噪声级（详见 §3.8 收官档案）。

### 1.5 基线数字（口径纪律=绝对数字跨口径不可比，只有同口径成对差值可比）

**v5 新基线（GRAPH_FORCE=1 时代）**：

| 口径 | 配置 | 图关 | 图开 | 证据 |
|---|---|---|---|---|
| cli 微基准（temp0、-p Hello、-st） | 27B-MTP / MTP n3 | 34.13（7轮 33.8-35.6） | **39.30±0.15** | n128 MD5×4 |
| cli | 27B-UD / 无MTP | 32.5（n2048 32.4） | **37.4**（n2048 37.9） | n128+n2048 MD5 |
| cli | A3B / 无MTP | 33.6 | **78.4 / 83.8(n2048)** | n128+n2048 MD5 |
| server 真实请求（378tok、全采样链、tensor） | 27B-UD | 21.9 / 22.9 | **32.2 / 32.5** | 两轮成对 |
| server | A3B | 23.2 | **61.5** | 单发成对 |
| server 对照（layer split） | A3B | 50.26 | 52.5-58.6 | 勿用于日常 |

**v4 旧基线（graph 关闭时代，勿与新表直比）**：贪心 Q8_0+MTP 37.73~38.65｜贪心 UD 32.2~32.6｜
创作 UD 29.3~29.5｜省电 3 卡 37.00｜synth a=4 f_Q8≈2.03。

【v7】**创作场景主基线 = server 全采样链 27B-UD = 32.2/32.5 t/s**。
【v8】图后创作口径整体优于 v5 锚点但**跨 prompt 不可直比**（诊断 A 三知悉：host 采样≈0 成本/
内容相关 ~2 ms/tok/跨 prompt 不可直比）——**重定标=下窗口必做首项**（§3.2），重定标前所有
绝对数字仅作参考。

【v7】**P21 口径漂移警告**：贪心口径从 39.3 漂至 44~47 区间（R22 探针1 40.5 出带判读为
未设 GRAPH_FORCE+无冷却所致）；绝对值跨窗口可能漂移，**动手前必重校准一发**；
下文所有 % 均为相对增量，不受漂移影响。【v8】R22 悬案已闭：实测 40.8±1.1 tok/s，44~47 判伪。

pp：图前 7,695tok 老口径 315.2（graph 不动 prefill）；系统性 pp 重测仍遗留（P18）。

### 1.6 研究意图

单用户单流 pp/tg 最大化；延续 qr0n 路线（fp16、压指令、压通信、压间隙、压宿主节拍）；
每改动独立构建+验证门+冷机 A/B，成果以 README/patch/commit 落账。**并发聚合不是目标。**
【v7】**主场景锁定=文学创作**（server 全采样链 + 262k ctx + 长会话马拉松），
质量与稳定性优先于峰值速度；贪心档保留为精确/对照口径。

---

## 【v7】1.7 PCIe 带宽 vs 延迟：认知纠偏专节（必读）

**用户直觉（已澄清）**：tensor 模式每轮都 allreduce，无 NVLink 时卡间单宽受 PCIe 带宽制约，
严重影响输出速度；增加/变相增加 PCIe 带宽=增加卡间带宽=解决 4 卡平台最大瓶颈。

**前半句对**：AR 确实每步都发生，卡间通信确实是 4 卡 TG 的显著瓶颈（**占 ~15-20%**）。
**后半句归因错**：瓶颈是**每次 AR 调用的固定延迟**（主机入队+同步+协议开销），不是带宽。

**数据推演（27B，d_model≈5120，tensor-split 4 卡，2.5KB/分片/层）**：

| 项 | decode（tg） | prefill（pp） |
|---|---|---|
| 每层 AR 数据量 | 2.5 KB | MB 级（7695tok×5120/4×2B≈19.7MB/层） |
| 每步 AR 总发送/卡 | ~0.4 MB（~100 次 AR × 2×(3/4)×2.5KB） | ~2.9 GB |
| 带宽时间 @12GB/s | **33 µs/步** | ~240 ms |
| 占比 | **0.1%**（30.8ms/tok 创作口径） | ~1% |
| 实测 AR 总开销 | **4-6 ms/步（15-20%）** | 计算占主导，AR <5% |
| 瓶颈归因 | **固定延迟**（22µs/设备/轮主机入队+同步+协议） | GEMM 计算 |

**三个决定性 A/B 证据（全部本仓库实测过）**：

1. **跨 UPI 跳 3-4% tg 惩罚**：若是带宽瓶颈，卡插哪个 socket 都该一样（带宽相同）；实际跨 socket 变慢
   → 是**延迟路径**（跨 socket P2P 硬件拒绝，必须经 CPU 内存中继 → UPI 往返增加固定延迟 ~15µs/跳 ×
   ~100 AR/步），不是带宽。
2. **32b9763 P2P staging 休眠**：同 socket 6/6 对 P2P 全通，代码已入库但热路径不激活——
   若带宽是瓶颈，启用 P2P 绕过 CPU 中继应显著加速；实测无感 → 带宽不是约束。
3. **GGML_CUDA_P2P 跨 UPI 10.7× 倒退**：强行 P2P 走跨根复合体路径反而更慢 → 问题在路径延迟，
   加宽链路无济于事。

**对外部项目评估的修订**：

| 项目 | 修订 |
|---|---|
| ThunderEP（DMA 引擎） | **降级为设计参考**：EP MoE 每 token 路由 top-k 专家，每步激活比 TP 环形 AR 大 10-100 倍，带宽才是其约束；llama.cpp TP 每步 KB 级消息，固定延迟才是约束，DMA 原则不适用。其"decode +1.26×"数字不可外推 |
| NCCL P2P BIOS 调优 | 维持拒绝（本机跨 socket P2P 硬件拒绝；llama.cpp 无 NCCL 路径） |
| pxa | 维持情报价值（PXQ 格式与 batch 几何先验，非 PCIe 带宽） |
| Ulysses 流水 | 维持拒绝（框架不符；其"通信-计算重叠"是延迟隐藏思路而非带宽扩容） |

**带宽类项目收益上限**：TG ≈0.1-0.3%，PP ≈1%——**均不作为独立战役立项**。

**真正能吃到那 15-20% 的方向（按可行性排序）**：

- ①**减少 AR 调用次数**（架构级层融合，P16 方向延伸）；
- ②**异步 AR**（b582586 已被 reset 带走，需重新评估；风险=与图捕获冲突）；
- ③**one-shot AR for small messages**（NCCL 对小消息的已知优化；ggml-cuda 自定义 AR 是否已实现
  待审计；收益=消除环形多跳的固定延迟部分）；
- ④拓扑优化（P06 已收尾，CVD=1,2,3 为现有最优解）；
- ✗ 图捕获 AR（P19-A 已判死）；✗ 增加 PCIe 带宽（收益上限 0.1-0.3%）。

---

## 2. 项目结构与补丁

### 2.1 目录与工具

patches\ 0001..0012*.patch；tools\（verify-source.sh / ggufinfo.py / **golden.ps1、mtp_test.ps1、
apply_nc.py.archived——【v8】已入库（98cbe9b），遗留条目作废**）；bench\sweep.cu；
data\q4k_one.sass（+【v8】kld_corpus.txt KLD 审计语料已入库；truth25593.bin 临时产物已 gitignore）；
README.md / README.zh-CN.md（权威）；HANDOFF.md 本文件（已入库，0133a37 起）。

【v8】原"工具入库六条命令"作废（先查账再动手：git log --all -- tools/ 考证 98cbe9b 早已入库，
认账㉛）。

D:\temp 现存：golden.ps1(v2)、mtp_test.ps1、apply_nc.py、ttype30.py、req_t285.json、t285.txt、
longprompt.txt、srv*.log、golden_*.txt、bin_old\、cli*.txt、trace*csv。

### 2.2 补丁/提交分工表（★=已应用并推送；☆=参考未应用；⊕=已开发否决回滚）

★ 0001 免重算 q8_1 块和(+4%)｜★ 0002 GP100 MMVQ 参数表(+33% 合计)｜★ 0003 放开 AllReduce｜
★ 0004 copy-engine 双流｜★ 0005 向量化 f32↔f16｜★ 0006 AllReduce N 设备(2.3x/+39%)｜
★ 0007 fp16 MMVQ(8B 2.03x)｜★ 0008 split-K｜★ 0009 delta-net 折叠(+9.1%)｜
★ 0010 cuBLAS-GEMM FA（fp32 默认=NaN 修复，FA_GEMM_PREC=16 逃生门）｜
☆ 0011 并发 agent｜☆ 0012 GQA tile GP100 限定｜⊕ 0013 Q8_0 多列 verify（-29~36%，全文存 apply_nc.py）｜
★ 32b9763 AR P2P staging（allreduce.cu +63/−2；任一对被拒整体回退 copy staging）｜
★ 3d19fc4 GRAPH_FORCE（ggml-cuda.cu +3/−1）｜★ 45e9e74 README 终版（153+/81−）｜
【v6】★ 6fb569d P2P staging 默认 0 可用性修复（+8/−1，fork 独有文件）｜
【v8】★ 5216f92 #25593 收窄修法（common.cuh:311 单行 && cc != 600）｜
★ de26e65 KLD 审计语料入库+gitignore truth base｜★ 2ce560c README 双语专节｜★ 0133a37 本文 v8。

**已知负结果（勿盲目重试）**：

- ~~CUDA graphs −1.4%~~ 已被 P12 推翻为"双卡特例"（fallentree 2 卡机器同款）；四卡机大赢 +15~149%。
- 多列 fp16 内核（Q6_K/Q8_0/IQ4_NL）：多列 fp16 仅对 ldg 型（8B 对齐直读 Q4_K/Q5_K/IQ4_XS）成立。
- 创作档 MTP（双模型实证）【v7】维持，p-min 重审判未做；GGML_CUDA_P2P 跨 UPI 10.7x 倒退；
  -ctk q8_0 在 sm_60 倒退；MMVQ 融合 −2.1%。
- graphs reused 计数器≠图开关证据——速度差=唯一 oracle（nsys cudaGraphLaunch 计数次之）。
- 【v6】P19-B+P20 AR 图内化双死刑（§6）。
- 【v7】增加 PCIe 带宽类项目（DMA/NCCL BIOS/P2P 路径）：TG 收益上限 0.1-0.3%（§1.7）。
- 【v8】MMVQ half2 decode 假说（#25593 修复侧贡献）：已关闭——prefill 16F=主毒源，decode 侧贡献
  低于 KLD 地板。

### 2.3 操作纪律（v4 全部有效 + v5 graph 时代追加 + v6/v7/v8 增补）

- **重建前必 taskkill /f /im llama-server.exe + ping -n 6**（LNK1104 教训）；LLAMA_UI_GZIP 警告无害。
- **日常关服=taskkill /f /im llama-server.exe**（多实例先 tasklist\|findstr 再 /pid 点杀；
  请求进行中勿杀）；图开时 Ctrl+C 退出 40-55s 属正常（图销毁税），勿误判为卡死。
- **env 纪律**：set 后必清+无等号回显验证（set GGML_CUDA_GRAPH_FORCE）；新配置新窗口；
  env 七件套：GRAPH_FORCE / AR_P2P / ALLREDUCE / P2P / NUMA / FORCE_CUBLAS / FA_GEMM_PREC。
- **PS5.1 三坑**：①单元素 JSON 数组折叠标量，取元素用 @($x)[0]；②thinking 模型 content 为空
  （token 在 reasoning_content），请求体加 chat_template_kwargs=@{ enable_thinking=$false } 并拼接
  reasoning_content（golden.ps1 v2 已内置）；③交付脚本必测目标机特性。
- **正确性验证门**：golden 三硬门（temp0+enable_thinking=false+固定英文提示+256tok，
  G1/G3/U1 三配置逐位一致；限不碰 attention/KV 的改动）；**M1 MD5 双臂模板**（cli temp0 双臂全文 MD5，
  n128 快筛/n2048 强证据）；触碰 attention/KV 仍必须触发阶梯。
  【v8 增补】**golden 探针已证盲区**（11-token 短 prompt 检不出 prefill 累积误差，见 §3.8）——
  数值敏感改动的权威门=**KLD 面板**（语料+truth base+16 分块对账+双臂比值，用法见 §3.8 档案），
  golden 降级为快筛。
- 冷机=ping -n 121 127.0.0.1 >nul；单发数字注明冷/热；mtp_test 两发取二发。
- 工具用法：golden.ps1 -Tag X（打印 md5/prompt_n/pred_n/tg）；mtp_test.ps1 -Tag X [-Mode creative]；
  findstr 不跨行。
- 1-token prompt 的 prompt 速度=固定开销噪声不可读；server 的 slot 首请求偏慢属暖机。
- 【v6】**回归门增补**：创作用 -sm tensor → issue #29466 同款二请求崩溃测试必跑；
  纯宿主重构（shinbunbun #11/#13/#28）要求 temp0 双臂 MD5 逐位同；#31 属算术改变，
  MD5 变化需登记为合法口径切换。
- 【v6】R22 纪律：命令逐字可贴、Bypass 永久、nsys --force-overwrite、server 必贴窗口A日志、
  版本宏不可作身份判据、R15-① 纯 ASCII。
- 【v7】每次测速前必验：set GGML_CUDA 回显（应仅 GRAPH_FORCE）+ ping -n 121 冷却（P21）。
- 【v8】native exe 一律 cmd /c "... > log 2>&1"（抗 EA=Stop 良性 stderr 击杀+可回查）+ 块首
  $ErrorActionPreference='Continue'；读写 UTF-8 文档一律 [System.IO.File] 显式 UTF8 no BOM；
  交付块每行尾加分号+追加操作前置防重复哨兵（认账㉗/㉜/㉝）。

---

## 3. 优化路径清单（v8 按创作场景重排）

### 3.0 已结项（勿再投入）

P01 TCC｜P02 MTP（贪心落地/创作关/A3B 尾巴选做）｜P05 配比盘点｜P08 fp16 MMVQ（单列生效、
多列否决）｜P11 并发（出局）｜P06 布局主体（跨 UPI 定量+省电档落地）｜P12 CUDA graph 解锁｜
【v6】P13 P2P（跨 UPI 10.7× 倒退 + 6fb569d 默认 0 + 探针4 加载期崩"peer access is already enabled"
签名新证→至少两种失效模式）｜【v6】P19"AR 图内化"（P19-A 回档/P19-B+P20 双死刑/Phase C 不启动；
残值创作口径 0.29%/tok、贪心 0.4%）｜【v7】增加 PCIe 带宽类项目（收益上限 0.1-0.3%，§1.7）｜
【v8】issue #25593 sm_60 FP16 carveout（5216f92 收官，KLD ≥977×，§3.8 档案）｜
【v8】P17 采样栈一期（诊断 A −1.29 ms/tok 证伪，收益上限不成立）。

### 3.1 【v8 修订】推荐主攻（P17 一期证伪降级、#25593 收官，主攻位重排）

0. **§3.2 重定标首项（必做，半日）**：图后创作口径跨 prompt 不可直比（诊断 A 三知悉），
   任何新战役的预注册带都需要重定标后的基线账本——不重定标则一切 % 不可信。
1. **P16 标准注意力 0009 式融合（主攻候选首位）**：+3~8%（保守 3~5%），17/66 层标准注意力。
   0009 折叠先例（+9.1% 逐位一致）证明路线可行，但 GDN 层结构不同、幅度不可外推；
   纯调度折叠可求逐位一致（golden+KLD 双门），含算术合并走 KLD 比值判据——验证资产已齐备。
2. **P07 时钟卫生（诊断先行，随重定标顺路）**：250W 墙 ~60s 节流 vs 创作马拉松主场景；
   诊断=30 分钟连续生成+nvidia-smi 时钟/功耗曲线，近零成本；坐实节流则升级并列主攻
   （长会话持续 +3~8%，峰值 0%）。
3. **GDN 四件套移植（shinbunbun #23/24/25/27）**：+1~3%，随行项（27B 有 49 层 GDN，
   仅 0009 部分覆盖）。
4. **AR 延迟导向新思路**（§1.7 末尾 ①②③：层融合减 AR 次数/异步 AR 重评估/one-shot AR 审计），
   需诊断后另行立项。

【v8 降级记录】P17 一期（shinbunbun host 三件套 #11/#13/#28，原预期 +5~9%）：诊断 A 实测
mean(A1,A2)−mean(B1,B2)=−1.29 ms/tok 落带外更低侧 → 采样链无可分离正成本（创作链 ~18%/tok
采样地板假说打穿），一期关闭；二期（DRY@256 GPU 化/降频、罚项融合，原 +2~5%）收益上限
需按重定标后数据重估，暂缓。
【v8 收官记录】#25593 修法已于 5216f92 落地并推送：tg 0%（噪声级）无速度油水，质量侧兑现
（KLD ≥977×、argmax 翻转 1.94%→0%、PPL 税 +0.35% 免除），档案见 §3.8。

### 3.2 廉价批（【v8】首项升级为下窗口必做；一个下午全带过）

**三档+MoE 重定标（GRAPH_FORCE=1 下重跑 golden/mtp_test 四档位，建立基线账本，含创作档图后首测；
顺路 P07 节流诊断=30 分钟连续生成+nvidia-smi 曲线）**｜P03 ubatch 512/2048 扫描（t285；
pxa 先验 -b 2048 -ub 2048 对照，URL https://github.com/poisonxa16/pxa；依赖 #31 kv-chunk 腾显存；
tg 不动只影响长 prompt pp）｜P04 FA_GEMM=0 tile vs GEMM @8k 再裁决（顺带记录 PR #26289 判 N/A：
head 128∉40-112）｜P06 剩余（bench r=3 复核 1+3 vs 2+2、CVD 变体）｜P10 AR bf16（**预注册 -2~0%**，
Pascal 无 BF16 硬件，转换内核吃掉节省）｜P18 longprompt pp 补测（素材已备）。

### 3.3 中期

**P16 标准注意力 0009 式融合**（主攻候选首位，见 §3.1）｜**P17 二期**（存疑待重估，见 §3.1 降级记录）｜
**P14 A3B 深挖**（基线 cli 83.8/server 61.5；勿 -ncmoe；PR #26264
https://github.com/ggml-org/llama.cpp/pull/26264 仅 A3B pp +10~25%（创作 27B dense=0%）；
PR #29184 https://github.com/ggml-org/llama.cpp/pull/29184 shared experts 融合）｜
GDN 四件套移植（shinbunbun #23/24/25/27：launch 折叠/内核/拷贝优化，27B 有 49 层 GDN，
仅 0009 部分覆盖；预期 +1~3%）｜#31 fattn-f16-kv-chunk（262k FA 计算缓冲 1152→192MiB，
tg 0% 但为 P03/图槽腾显存）｜P09 cublasLt 组合（+1~3%）。

### 3.4 远期

P15 自研 fp16 GEMM（pp+5~15% 高风险）｜ldg 型 Q8_0-nc（低优先级）｜
qwen3.9 移植清单（速度 0% 质量期权，分钟级）｜--spec-draft-p-min 创作档重审判
（URL https://www.neoteric.no/blog/llamacpp-spec-draft-p-min-mtp-qwen3 +
https://github.com/ggml-org/llama.cpp/pull/22397；预期 **-1~+4%**，≤0 则创作 MTP 永久关闭
一次性了断；贪心档 +3~7% 可先试；创作档双模型负实证未撤销，重审判属有条件重开）。

### 3.5 【v8 修订】下窗口建议打法

① 0.2 协议开局：通读→§3.2 重定标首项（必做半日，顺路 P07 节流诊断）→主攻立项
（§3.1：P16 首选）→预期%→用户确认→诊断模式；
② 两发悬案已闭勿重开（R22=40.8±1.1 判伪 44~47；诊断 A=P17 一期关闭）；
③ 数值敏感改动一律过 KLD 面板（§3.8 档案），golden 已降级为快筛；
④ 每改动独立构建+验证门+冷机 A/B，落账 commit/README。

## 【v6】3.6 创作场景重估总表（主场景；基线 32.2/32.5，动手前先重校准）

| # | 措施 | 来源/URL | 创作口径预期 |
|---|---|---|---|
| 1 | P17 采样栈一期 = shinbunbun host 三件套 | https://github.com/shinbunbun/llama-cpp-p100-patches | **证伪关闭**【v8】（诊断 A −1.29 ms/tok） |
| 2 | issue #25593 carveout 修复 | https://github.com/ggml-org/llama.cpp/issues/25593 | ✅ **已落地 v8**：tg 0%（噪声级）；KLD 全分位 977×~9.1×10³ |
| 3 | P17 二期自研（DRY GPU 化/罚项融合） | 自研 | 需按重定标后数据重估【v8 存疑】 |
| 4 | P07 时钟卫生 | 自研 | 持续 **+3~8%**（【v8】诊断先行随重定标） |
| 5 | GDN 四件套移植 | 同 shinbunbun | +1~3% |
| 6 | P16 注意力融合 | 自研 | +3~8%（保守 3~5%）【v8 主攻候选首位】 |
| 7 | #31 fattn-f16-kv-chunk | 同 shinbunbun | tg 0%；使能 P03 |
| 8 | P03 ubatch 扫描 | https://github.com/poisonxa16/pxa | tg **0%**；pp +0~10% |
| 9 | --spec-draft-p-min 创作重审判 | https://github.com/ggml-org/llama.cpp/pull/22397 | **-1~+4%** |
| 10 | PR #26264 | https://github.com/ggml-org/llama.cpp/pull/26264 | 创作 27B dense=**0%**；仅 A3B pp +10~25% |
| 11 | qwen3.9 移植 | 内部清单 | 0%（质量期权） |
| 12 | P09 cublasLt | 自研 | pp +1~3% |
| 13 | P15 fp16 GEMM | 自研 | pp +5~15%（高风险远期） |
| 14 | P10 AR bf16 | 自研 | **-2~0%**（预注册负） |
| 15 | G64 格式 | https://huggingface.co/fallentree/Qwen3.8-27B-Uncensored-GP100-GGUF/blob/main/DESIGN.md | **不推荐**（质量降级与文学创作冲突） |
| 16 | A3B 换引擎（场景选项） | 本 fork 已支持 | **+89%**（61.5 vs 32.5，质量用户定） |
| 17 | 【v7】增加 PCIe 带宽类 | ThunderEP/NCCL BIOS 等 | **TG 0.1-0.3% / PP ~1%**（§1.7，不立项） |

【v8 修订】**创作目标**：重定标（半日）→ 2~3 会话内基线→**+8~14%**（P16 主攻+P07+随行项）；
质量修复（#25593）**已完成**；长会话稳定（P07 诊断先行）。

**合并台账（原计划 × 外部项目，去重）**：P17←shinbunbun 三件套（一期证伪关闭 v8，二期存疑）；
P03←pxa 先验+#31 使能；P16 与 GDN 四件套互补（17 标准层 vs 49 GDN 层）；
P14 A3B←#26264+#29184；P13/AR 内化/创作 MTP（无 p-min）/#26289/G64/AR bf16/DP/NCCL BIOS/
Ulysses/ik -ot·-ser·NUMA/P11/P06 = 关闭清单。

### 【v6】3.7 外部核查档案（全 URL，防遗漏）

| 项目 | URL | 状态 |
|---|---|---|
| shinbunbun/llama-cpp-p100-patches（29 补丁，v0.4.0 基线） | https://github.com/shinbunbun/llama-cpp-p100-patches | 【v8】一期三件套证伪关闭；GDN 四件套 #23/24/25/27 仍为移植来源；docs/benchmarking.md 作者自评比补丁更可复用 |
| issue #25593 sm_60 数值精度 | https://github.com/ggml-org/llama.cpp/issues/25593 | 【v8】已修复收官（5216f92；本机 KLD 分位 977×~9.1×10³、tg 0%，§3.8 档案） |
| apollo-mg gist（KLD 方法论） | https://gist.github.com/apollo-mg/9218d50a209d70a85f033bf182657818 | 指出 build 内对拍看不到此 bug（共模误差）；【v8】其方法论已落地为本 fork KLD 面板（§3.8） |
| 修复参考实现 | TheTom/llama-cpp-turboquant#212（已合并）、spiritbuun/buun-llama-cpp#80（上游未合并） | 【v8】本 fork 取更窄单点修法（仅 :311），保住 0007 收益 |
| PR #26264 MMQ-for-MoE sm_60 | https://github.com/ggml-org/llama.cpp/pull/26264 | A3B pp 专用；"+100% TP"说法未能核实勿引用 |
| PR #26289 FA tile head 40-112 | https://github.com/ggml-org/llama.cpp/pull/26289 | N/A：head_dim=128 ∉ 40-112 + 0010 绕 tile |
| PR #22397 / p-min 博客 | https://www.neoteric.no/blog/llamacpp-spec-draft-p-min-mtp-qwen3 | 创作重审判；Ian Paterson 扫描：MTP 翻盘 |
| PR #29184 shared experts 融合 | https://github.com/ggml-org/llama.cpp/pull/29184 | P14 专用 |
| issue #29466 tensor split 二请求崩溃 | https://github.com/ggml-org/llama.cpp/issues/29466 | 回归门必跑（创作用 -sm tensor） |
| pxa Pascal/Volta 引擎 | https://github.com/poisonxa16/pxa | 情报：4×P100 batch 几何 -b 2048 -ub 2048；PXQ 格式；LoopSpec |
| fallentree GP100 GGUF DESIGN.md | https://huggingface.co/fallentree/Qwen3.8-27B-Uncensored-GP100-GGUF/blob/main/DESIGN.md | 情报富矿：G64=Q4_0 码率+Q4_1 对齐，issue-bound 下 +10~21.8%（16k/64k reuse）；Q4_K 在 GP100=2.3× 解码税；head_dim=128 实锤；--ctx-checkpoints 8 为 GDN 多轮必需；FA tile pin −6% 回滚；h2acc_ne=4 胜/8 因 acceptance 降被拒；其"2 卡 graphs 无效"即本项目 README 双卡特例出处（被四卡数据反向修正） |
| fallentree/llama.cpp-gp100 | https://github.com/thefallentree/llama.cpp-gp100 | 运行时参考 |
| ThunderEP 论文 | https://arxiv.org/abs/2609.40093 | 【v7】降级为设计参考（EP≠TP，带宽论不适用） |
| UCCL-EP | https://arxiv.org/abs/2512.19849 | 同类参考 |
| ik_llama.cpp issue #627 | https://github.com/ikawrakow/ik_llama.cpp/issues/627 | 4×P100：vLLM 20 t/s vs llama.cpp row-split 10 t/s；vLLM 1.0 将弃 Turing 以下 |
| Eanya-Tonic/2080ti-minimax-h3 | 未能核实存在 | 拒绝（框架不符） |
| shinbunbun issue 反馈 #29466 | 同上 #29466 行 | 移植后重点回归 |

### 【v7→v8】3.8 诊断 B → #25593 收官档案

**执行命令（v7 已跑）**：

```cmd
findstr /n "610" D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\common.cuh
findstr /n "fast_fp16" D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\common.cuh
findstr /sn "CUDA_R_16F CUDA_R_32F" D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\ggml-cuda.cu
```

**实测输出要点（v7）**：

- common.cuh:51 GGML_CUDA_CC_DP4A=610 宏定义
- common.cuh:261 宏门 `#if defined(FP16_AVAILABLE) && __CUDA_ARCH__ != 610`
- common.cuh:305 fast_fp16_available 含 `ggml_cuda_highest_compiled_arch(cc) != 610`
- common.cuh:311 fast_fp16_hardware_available 含 `cc != 610`
- ggml-cuda.cu:1372 trait data_type=CUDA_R_32F；:1400 trait data_type=CUDA_R_16F；:1618 选择逻辑

**判读（对照预注册"三行 !=610 都在且无 600 豁免=未免疫"）**：三道门禁全部在位且**仅豁免 610、
无任何 600 carveout** → 对 cc=600（GP100）三道门全放行；sm_60 下 dequant+cuBLAS 权重 GEMM
compute type 走 CUDA_R_16F——0010 的 fp32 默认只覆盖 FA-GEMM，**FFN/projection GEMM 静默半精度实锤**。

**【v8】修法勘误（v7 原预注册两处已证伪）**：

- ~~三处 != 610 补 600~~ → **单点收窄修法=仅 common.cuh:311 fast_fp16_hardware_available 补
  && cc != 600**。理由：:261 宏门与 :305 编译门管控 half2 内核编译路径（vecdotq.cuh:157/228/271
  依赖 FAST_FP16_AVAILABLE=0007 的 2.03× MMVQ 收益命脉），改之即杀收益；MMQ 调用点
  ggml-cuda.cu:1954 在 sm_60 不可达故无需处理；实际目标调用点=:1627/1628（cuBLAS compute type）。
- ~~修复后 golden MD5 必变=唯一合法变化~~ → **实测位级不变**：11-token 贪心探针盲区
  （短 prompt 极少命中毒位 + f16 KV 吞掉 prefill 累积误差）。教训=门先验必须随修法适配（认账㉓）；
  golden 由此降级为快筛，数值正确性权威门=KLD 面板。

**【v8】战役收官档案（2026-10-17~18，commit 5216f92 已推送）**：

- 修法落地=5216f92（1 file changed）。附带披露：GGML_CUDA_FA_GEMM_PREC=16 逃生门经 :1628
  被设计性强制回 FP32。
- KLD 终审（4×P100，16 分块对账，truth base=f32 KV/-fa off/ctx512/chunks16、PPL 2.5724、2.03GB；
  语料=data/kld_corpus.txt=tools/server/README.md 108KB——调了一个月 server、拿它的说明书审计它，
  自指闭环）：
  - 修复前（BUGGY 臂）：mean KLD 0.003704±0.000224、Same top p 98.064%、Max Δp 37.9%、
    RMS Δp 2.240%、PPL 税 +0.35%；损伤形态=沉默投毒（median Δp −0.002% 而 99.9% 位 +22%）。
  - 修复后（NEW 臂）：Max KLD 0.000055、Same top p 100.000%、RMS Δp 0.001%、mean 低于显示精度
    → **全分位提升 977×（95% 位）~ 9.1×10³（Max）**。
  - 交叉验证：apollo 面板 top-token 一致率 96.53% vs 本机修复前 98.06%，同族指纹。
  - 假说清算：MMVQ half2 decode 贡献关闭（prefill 16F=主毒源，decode 侧低于地板）。
- 速度侧：tg 0%（探针 35.148→35.423、创作口径 ~28.6 持平，噪声级）——修复设计上不碰 decode；
  pp ±1% 预注册带兑现（PPL 税免除）。
- 沉淀：**KLD 数值审计面板=常设闸门**（语料 data/kld_corpus.txt 已入库 + truth base 重建流程 +
  16 分块对账 + 双臂比值判据）。未来一切数值敏感改动（P16/GDN/新量化格式）必修此门；
  重建 truth base 一条命令模板见仓库 commit de26e65/2ce560c 相关注记。

---

## 4. 遗留事项（【v8】大扫除）

- ~~工具入库（§2.1 六条命令）~~【v8】**已闭合（ghost）**：98cbe9b 早已入库，遗留条目作废（认账㉛）。
- ~~HANDOFF.md 本身入库~~【v8】已闭合（0133a37 起在库并推送）。
- F1"真免 env 终验"：GRAPH_FORCE 缺省行为已验证，其余 env 的零 env 终验可顺手做。
- issue #4 等 qr0n 验证；0013 形式 PR 未承诺。
- pp 系统性基线在 262k 新配置下未建（并入 §3.2 重定标/P18）；插槽 1+3 vs 2+2 待 bench r=3 复核（P06）。
- A3B server 无图臂成对比值已补齐（R41）。
- ~~Round 22 收官三 commit 流程~~【v8】已闭（b7ad818 已推送）。
- ~~Round 22 复测悬案~~【v8】**闭合**：server 贪心实测 40.8±1.1 tok/s，44~47 区间判伪
  （口径漂移第三次实锤）。
- ~~诊断 A（采样成本定界）~~【v8】**闭合**：mean(A1,A2)−mean(B1,B2)=−1.29 ms/tok 落带外更低侧
  → P17 一期关闭（§3.1 降级记录）；三知悉已固化 §1.5。
- 【v7】--ctx-checkpoints（GDN 多轮对话，fallentree 生产实践建议 8）：待查本构建是否在位。
- 【v8】可选：README 专节补上游显式 URL（github.com/ggml-org/llama.cpp）。

---

## 5. P12 战役档案（v5；细节以 README 专节与收卷摘要为准）

### 5.1 commit 链（GitHub key-sh/p100-gp100-fp32）

7bc6d4e（ggumeta.py）→ 32b9763（P2P staging 休眠）→ 3d19fc4（GRAPH_FORCE 解锁）→
45e9e74（README 终版）→【v6】6fb569d（P2P staging 默认 0）→
【v8】b7ad818（AR docs）→ 5216f92（#25593 收窄修法）→ de26e65（KLD 语料+gitignore truth base）→
2ce560c（README 双语专节）→ 0133a37（本文 v8）。

### 5.2 nsys/trace 档案

cli_ar1(66.2/21.8,LaunchKernel81832)/ar2(70.9/20.9)/ar3(66.5/22.1,offset 0/14.8/34.3/67.3)/
ar4(68.9/22.4)/map(-ts28,26.4)/**graph(54.5/22.4,GraphLaunch3612,LaunchKernel59352,
Δlaunch=−22480,offset 0/10.8/19.3/40.9,med555)**；trace1/3/4/M/G csv。
图前轮 651µs→图后 570µs（按 launch 数预测 −88µs、实测 −81µs，误差 ~10%——最可迁移数字）。

### 5.3 方法论（v5 沉淀）

预注册判读树（先写预期带后测）｜守恒律｜MD5/temp0 双臂腐坏探测（M1 模板）｜关键路径先验｜
**速度差=图开关唯一 oracle（计数器作废）**｜退出秒数 2×2 判别器｜1-token prompt=固定开销噪声｜
server graphs reused≠重放证据。
【v8 增补】KLD 双臂对账（语料+truth base+分位比值，主判据退化时切分位）｜DLL 时间戳链=构建身份
金丝雀｜cmd /c 重定向=原生命令唯一安全模式。

### 5.4 认账封卷（教训索引，新对话避免重蹈）

①6144 实例计数错 ②B/A 臂反号 ③pool 主带落空 ④V3 次数 ⑤R15 宿主税首述不准
⑥R18 两笔 ⑦摘要遗漏（→立固定末尾纪律）⑧api 半盲 ⑨R23 $_/$r ⑩R24 两翻案 ⑪R25 签名错置
⑫R26 C2 相位 ⑬R33 A3B 幅度失准（跨模型外推须重测）⑭graphs-reused 计数器误读 ⑮server 阈值
≥70 未命中 ⑯R35 条件预注存目 ⑰双仓库模型误判 ⑱未验证即断言（纪律：任何 git/文件状态断言必须
基于当轮真实输出）。
【v6】⑲**P21 口径漂移两次**（GRAPH_FORCE 未设+无冷却——探针1 40.5 出带即此因）。
【v7】⑳**"PCIe 带宽=卡间瓶颈"认知偏差**（AR 每步发生且占 TG 15-20% 属实，但归因=固定延迟
而非带宽，带宽仅 0.1-0.3%；§1.7 专节已固化推演与三证据）。
【v8】㉒tip 断言未实跑 §0.1 命令组（避坑①家族）｜㉓"golden 必变"门未随收窄修法适配→假红旗
（探针盲区）｜㉔--version 不可判身份（判据=git log+DLL 时间戳+diff）｜㉕PS 多行块粘贴截断→
全单行纪律｜㉖行内 throw 不阻断逐行粘贴→拆块制+块首重验｜㉗native exe 直连 PS 管道在 EA=Stop
持久会话被良性 stderr 击杀→cmd /c 重定向入日志+EA=Continue｜㉘固定 Tail 窗截数据→
Select-String 精确抓取｜㉙KL 模式输出格式外推失误→按日志实貌改判｜㉚主判据 median÷median
数值退化（修复太好分母消失）→预注册兜底条款切分位比值｜㉛遗留清单未查仓库账→tools ghost
（98cbe9b）｜㉜默认编码读写 UTF-8 文件（mojibake 虚惊+Add-Content ANSI 地雷）→[System.IO.File]
显式 UTF8 no BOM｜㉝跨行粘贴粘连→每行分号防御+追加前防重复哨兵。

### 5.5 日常指引速查

setx GGML_CUDA_GRAPH_FORCE 1（异常先 =0 复验）；27B ubatch 4096/batch 8192（2GB 余量紧张 OOM 退 2048）；
A3B ubatch 1024/batch 4096 可试 2048；关服 taskkill /f /im；正确性抽验 M1 模板；
【v8】数值敏感改动过 KLD 面板（§3.8）。

---

## 【v6】6. P19 战役档案（AR 图内化判死）

- **判决**：P19-A（图捕获 AR）跨设备同步原语不兼容 → 已回档；P19-B+P20 双死刑；Phase C 立项不启动。
- **残值**：AR 入队残留 ~22µs/设备/轮 ×4 卡≈88µs/轮 → 创作口径 88µs/30.8ms=**0.29%/tok**、
  贪心 0.4%——判死损失可忽略；P17 采样栈不受牵连（采样=纯宿主代码，无需图捕获，机制不同）。
- **本窗口最终代码成果**：6fb569d（P2P staging 默认 0，+8/−1，fork 独有文件，qwen3.9 移植分钟级）。
- **四指纹**：b7bcd09d / efa2caeb / f76ced98 / 4aa1530b。
- **探针记录**：探针1 文本 golden 同（Generation 40.5 出带=口径漂移悬案，【v8】已闭=40.8±1.1 判伪）；
  探针2 3 卡 41.3 t/s 跑满 256 tok 不崩+文本逐字同（修复本体成立，AR 路径切换数值按构造不变获实测背书）；
  探针4 P2P=1 加载期崩（sticky error "peer access is already enabled"，与 32b9763 当年 draft 起步
  脏数据签名不同 → **P2P 至少两种失效模式**：内存序嫌疑+double-enable 类初始化缺陷，未证明；
  "=1 即武装"结论不变；4 卡历史不炸更顺理：mesh 首对失败→整体回退→从不 double-enable）。
- **后续方向**：§1.7 末尾 ①②③（层融合减 AR 次数/异步 AR 重评估/one-shot AR for small messages 审计）。

<!-- ===== HANDOFF.md v8 结束 ===== -->

<!-- ===== HANDOFF.md v8.1 增补段（追加于 v8 结束标记之后；v8 正文 L1-593 未动，只增不删）===== -->

## 【v8.1】7. wave1 host 补丁战役档案（#11+13+21，+5.5%）

### 7.1 判决与数字
- 战役：作者五件套 host 侧三件（#11 penalties-direct / #13 sampler-prefilter / #21 sched-reset-lazy）打包 wave1。
- 文档层级：本节为详细档；README.md 与 README.zh-CN.md 末尾各有面向用户的摘要专节，三件套同 commit 同步（冲突以 README 为准）。
- 判决：合并入主分支。三独立 commit f5aadb6(#11,+42) / 164a88e(#13,+178,-5) / d59c2f8(#21,+37,-2) 已 push myfork；行数 forensic 257/7 与 W1 diff --stat 逐字吻合。
- 速度：ABBA R27（a=OLD 33.94/34.59；b=NEW 36.52/36.23；c=NEW 36.44/36.21；d=OLD 34.40/34.94）→ 配对 b-a=+6.16%、c-d=+4.77%，总体 NEW 36.35 vs OLD 34.4675 = +5.46%；前会话复现（OLD 8 读 34.581 vs NEW gold 36.49 = +5.52%）；OLD/NEW 分布零重叠。
- 口径 A 基线：34.42 → 36.35 t/s（R27 b/c 均值）。B/C 口径未复测，下次跑相应模型时重锚。OLD 基线参照物封存：D:\temp\r26bin_old（063e9b1 二进制）+ 34.585/34.581 数字档。
- 放大机制：作者单卡口径 #21 单件 +0.94%；本机四卡张量并行 decode 为宿主编排绑定（J2b 宿主空转 55-60% wall）→ host 侧节省放大约 4 倍。pp 持平 / tg 独涨指纹成立。
- anchor 记录：a2 in-band [34.2,34.7]；d2=34.94 超带上沿 +0.24，方向保守（最保守交叉配对 36.21/34.94 仍 +3.6% 地板），入档不阻塞。

### 7.2 golden 三硬门（持久基准，候选构建必过）
- G1 贪心正文 MD5：固定 prompt 128tok temp0 → 7ddfbfe1aa5339aa6622f51b2c24fbec。
- G2 全概率哈希（KLD 等效，位级强于分位比值口径）：n_probs10 全位置 top10 概率数组哈希 → 75c7b773f22c7434daa6ac59c72d5b49（probs_n=64）。
- G3 #29466 二请求（同 slot 两个不同 prompt cache_prompt=true）：G3a=dc6f500426ecc74f78e13839ae37cc3d、G3b=a88b048dbe37fdf3a63a72116fb13941。
- 基准文件 D:\temp\g_hash_old.txt（063e9b1 构建生成）；wave1 NEW 侧 4/4 逐位 PASS。以后候选构建只重跑 NEW 侧（换后缀）比对。
- 勘误链：G2 首轮失败为读取侧编码（认账 53），数据本身从未异常——修复自校验=纯 ASCII 三行与首轮逐字同。

### 7.3 方法论增补（接 5.3）
- 多 hunk 补丁先 @@ 普查或 --reject（git apply --check 同文件首败即中止后续 hunk 检测，认账 54）。
- server 多臂操作命令必须物理写全每一条，引用式缩写一律禁止（认账 50/51/52 同族）。
- PS 5.1 读 UTF-8 文件一律显式 -Encoding UTF8（认账 53）；写 UTF-8 用 [System.IO.File] 显式 no BOM（认账 32 再确认）。
- golden 现场重建法：OLD 基线二进制现场生成基准（g_hash_old.txt）优于翻历史存档（同 session 同条件）。

### 7.4 认账增补（5.4 续；ASCII 编号防编码坑；44 编号未见于累积摘要，待查）
- 43 漏 --directory 导致补丁落错层。
- 45 目标版本未取证（v0.5.0）。
- 46 框架缺失推断错误。
- 47 P2 图样误读。
- 48 PS foreach 接管道。
- 49 gap_sum_ms 单位标注错（ms 实为 µs；busy+gap=wall 一致性检查救场）。
- 50 引用式命令一：W2 server 启动写同某臂 → 用户无命令可贴、探针空转。
- 51 引用式命令二：R19 包臂 b/c/d 同臂 a 仅两处替换 → ABBA 破坏成 OLLL；硬规则=多臂命令物理写全。
- 52 引用式命令三：惯用 golden fixture 依赖摘要外知识未带字面命令；golden 三硬门定义与实现入档。
- 53 Get-Content 缺 -Encoding UTF8：GBK 误读 UTF-8 多字节破坏 JSON（铁证 token 鈥? bytes[226,128,166]=U+2026 被吞半字节）；规则=读 UTF-8 显式 -Encoding UTF8。
- 54 git apply --check 同文件首败即中止 → J4 判 22 仅 1 hunk 败为伪影；22 实为 22 hunk、核心区 API 断层需语义移植；纪律=@@ 普查或 --reject。

### 7.5 wave2 前瞻（#22 decode-sched-slots）
- 规模：2 文件 22 hunk（.cpp 21 + .h 1）。作者基线 API：gf_res_prev_active / get_gf_res_prev() / sched_active()；本树 0.5.0：gf_res_prev(unique_ptr) / 无 active 标志 / sched.get()。第一组映射：gf_res_prev_active = nullptr 与 gf_res_prev->reset() 对应（memory_update L813 与 graph_reserve L2417 位置精确对齐）。
- 判性：.h hunk 直接落（上下文匹配 + sched_active inline 自洽）+ 手工加 gf_res_prev_active 成员一行；.cpp 机械约 13 hunk（sched.get → sched_active）--reject 批量；手工 3 处（#4/#14 映射 + #15 插入锚点）；语义重写 2 处（#5 process_ubatch 主改写约 104 行 + #6 alloc 回退约 69 行，get_gf_res_prev() 翻译为 gf_res_prev.get()）。
- 门：golden 三门位级全过 + WARN 门（decode slot cannot hold this graph 稳态禁现 = slot 池被放弃即补丁白打）+ graphs reused 降级为记录项（slot 命中会改计数，方向=更多复用）。
- 状态：【v8.2 更新】#22 已执行完毕并判死（不可 ship），全程档案见 §8；+5.5% 已入账，wave2 余下件为可选项非欠债。

<!-- ===== HANDOFF.md v8.1 增补段结束 ===== -->

<!-- ===== HANDOFF.md v8.2 增补段（追加于 v8.1 结束标记之后；v8/v8.1 正文未动，只增不删）===== -->

## 【v8.2】8. #22 decode slot pool 战役档案（移植→验证拦截→取证→判死）

### 8.1 判决
- 战役：作者 wave2 首件 #22（decode slot pool：小型 decode 图保留独立 llm_graph_result+专属调度器，命中即整图重放）移植；预期 +1~3%（wave1 宿主编排绑定红利的同一区）。
- 判决：**不可 ship（DO-NOT-SHIP）**。移植本身收官（cpp 4456 行+.h 426 行、五片段 .rej 权威序终审全过、构建绿、dll 活性 W1 六中），验证阶段确定性拦截：同二进制同旗标同请求序列，池武装→第二请求（原生 /completion+n_probs）launch 即崩 **GGML_ASSERT(ggml-backend-meta.cpp:2020 bcj.nodes[i]) failed**；池解武（LLAMA_DEC_MAX_TOK=0）→四探针全过且与 OLD 臂位级全同（BITS=4/4 PASS、graphs reused 127/189/219/220 逐字同）。ABBA R28 取消；README 无新增；wave1 +5.46% 分毫不差。
- 定性（R54 上游检索修正）：同类 issue **#29466**（同 assert 行 2020、同 request-1 OK/request-2 崩、同 P100+-sm tensor、上游 v0.4.0 无槽池亦可触发）→ #22 非孤立缺陷，而是**确定性暴露上游"图保持×meta 重建"既有脆弱面**；旁证 #30075（同面另一症状）与 draft #24549（TP 下 graph reuse 兼容草案）。反馈路线=在 #29466 下补充证据评论，不开新帖。

### 8.2 取证定案（R53 源码解剖，>85% 置信）
- 冲突面：main+4 slot 五个调度器共享同一 meta backend 实例（同 backend_ptrs 创建）→ 共享 uid/backend_configs；KV buffer=跨调度器共享 meta buffer；重建即翻代清空注册表（ggml-backend-meta.cpp L1996-2004）而 simple_tensor 仅搜当前代（L452/L481-484，查无返 nullptr→断言）；槽池让旧图跨请求存活，任何其他 uid 的图重建即摧毁其注册。崩溃路径仅多卡 TP（meta backend 专属），单卡不可能触发；且需混合图序列（不同 uid 交替=混合端点/混合形状）。
- 独立修复判不可行（把握<40%）：治本必动 ggml-backend-meta.cpp=wave1 地基（风险纪律禁止）；#22 内规避式修复对不准观测崩溃点且废跨请求价值。

### 8.3 代码保全、重启路径与收官后状态
- 归档分支 **archive/22-decode-slotpool**（commit 注记 DO-NOT-SHIP+#29466 交叉引用）；主线回 b669e86 干净基线（.rej 已删）。
- 上游若给出修复指引：checkout 归档分支→按指引改码→重跑 L1-L6 位级四探针+WARN 门→全过再议 ABBA R28（合并线 ≥+0.4% 不变）。
- 【v8.2 收官后 §0.1 预期状态更新】tip≥b669e86+本 v8.2 commit、树干净、分支 p100-gp100-fp32、**另有归档分支 archive/22-decode-slotpool**（勿在其上做新战役）。

### 8.4 基线勘误与门套演进（接 §7.2）
- §7.2 存档四哈希（7ddfbfe1/75c7b773/dc6f5004/a88b048d）=063e9b1 时代 rig 专属；r28bin_base（b669e86 tip，含 wave1）时代现场重建基准=**D:\temp\g_hash_old_r.txt（G1 ee213b33 / G2′ 373ec40b / G3a 47aeb7a7 / G3b 8772366b）**；两代 prompt_n 16→35 铁证模板渲染漂移（认账74），跨时代锚点只作软参考。
- 探针家族价值实证：G2′（原生 /completion+n_probs）=四探针中唯一踩原生路径者=唯一抓到崩溃者（§2.3 #29466 回归门的扩展落实：回归门=G1+G2′+G3a+G3b 全套）；G1/G3 结构上抓不到此崩。
- 证据包（D:\temp 易失，重要件建议另行备份）：srv_r_new.crash.log、srv_r_new_b0.log、bcj_assert_context.txt、g_hash_old_r.txt、g_hash_new_r.txt（后两者 4 行 172B）。

### 8.5 认账增补（接 §7.4 的 54；55-68 系 #22 移植期、未转录本档、详见战役累积摘要，其操作纪律已由 §2.3/§7.3 继承）
- 69 golden 命令未入库→L619 现场重建原则实例化；70 PSReadLine 会话死角（㉕㉖同族）；71 命令包依赖链显式化（V1→V2…逐链标注）；72 活性三件套（tasklist/netstat/health）=一切请求包前置硬门；73 最小化服务器窗口=服务器本体（勿点勿关勿 Ctrl+C；关服唯一合法=taskkill /f /im；^C 回显入日志=人为中断铁证）；74 跨时代锚点软参考（先验 prompt_n/渲染等价再谈位级）+R28 OLD=r28bin_base 含 wave1（非 063e9b1）；75 对照组判案（同请求 OLD 成功+NEW 失败⇒差异锁定臂）+ABORT 先活性后处置。
- 76 崩溃签名入档（GGML_ASSERT+文件:行号；fatal 扫描词表必含 GGML_ASSERT；VRAM 落回空闲=进程死亡旁证）；77 [IO.File]::WriteAllLines 长管线数组串化成单行（落盘后必 ReadAllLines 行数自证；comparator 数据比对与格式守卫分离报告）；78 decode graph slots 武装信号 lv3 不可观测（armed/disarmed 均 0 命中）→池类改动武装验证以行为学 A/B 为权威；79 假说预注册制度（取证前书面假说+CONFIRM/REFUTE 判据，防事后拟合；采证前修正概率须明示理由）；80 结构性 CONFIRM≠修复可行（治本触碰已 ship 地基或修复未对准观测崩溃点→判把握不足转外部反馈）；81 同签名上游检索（assert+文件+行号）为反馈前必做、命中即评论不开新帖、"补丁自身缺陷"vs"确定性暴露既有脆弱面"判决等价但话术必须区分。

<!-- ===== HANDOFF.md v8.2 增补段结束 ===== -->


---

## 【v8.3】重定标收官 + P0 战役记录（2026-10-18 窗口，tip=2841a9c）

### 重定标新基线（mtp_test.ps1 暖发为准）
| 档 | 模型 | 新基线 tg | 探针 | 参照 | 增益 |
|---|---|---|---|---|---|
| 贪心 | I:\ 27B-MTP-Q8_0 + spec-mtp draft-3 | 44.75 | summarise | 图前 37.7~38.7 | +15.7~18.7% |
| 创作（主场景） | G:\ 27B-UD-Q8_K_XL | 36.75（GF2=36.93） | creative | v5 锚点 32.2/32.5 | +12.7~14.1%（跨 prompt 注记） |
| 省电 | I:\ 27B-MTP + CVG=1,2,3 + ctx131072 | 41.94 | summarise | 图前 37.00 | +13.4% |
| MoE | G:\ 35B-A3B-UD-Q6_K_XL | 84.66 | summarise | 旧口径 61.5（R39/R41，探针差异待考古勿直比） | +37.7% |

### P0 战役判决（2026-10-18）
- 本窗口 3 崩（RC2/RC5/SA2）+ 昨晨 G2' 崩根因 = **#22 判死后 23:35 llama.dll 残留主线 Release（decode slot pool 缺省武装 dec_max_tok=4）**；wave1 双重洗清；R6"主线实证上游脆弱面"撤回。
- 三线定案：findstr LLAMA_DEC_MAX_TOK 二进制指纹 + archive 源码默认值 + 同二进制解武 A/B（armed 3/3 崩 vs disarmed 2/2 过）。
- 修复闭环：重建 19:08 llama.dll（无池指纹）→ GF1/GF2 双过 → 同实例 125+ 请求零崩零 assert。
- G4 门（同 prompt 二连发）四档抽查全过（GF2 / RG1+2 / RS1+2 / RM1+2）。
- W spec/set_sampler CPU sampler 回退 = SPLIT_MODE_TENSOR 系统行为，良性，基线已含开销（CVG 环境假说已证伪撤回）。
- 证据：D:\p0_evidence（36 文件+llama_dll_2335_22build.dll）；D:\r26bin_keep（94 文件）；srv_fresh/srv_greed/srv_save/srv_moe.log。

### 新增认账 84-100
84=PS 执行策略；85=先取证后重启+换日志名；86=G4 二连发探针；87=批量协议形状审计；88=一窗一标一命令；89=WER offset+PE 时间戳废；90=形状组活性闭环；91=二进制身份=DLL 链+行为学指纹；92=源码回退≠二进制回退；93=DLL 链开局必查；94=env 验证按前缀；95=每轮末尾累积摘要必附；96=挂机协议唯一化；97=生成式 soak 确定负载；98=1-tok 早停 EOS 行为学；99=采集包模式完备性；100=tensor 模式 CPU sampler=模式级系统行为，归因先查模式约束再查环境。

### 挂账
#29466 补充评论（保守措辞已备）；issue #23322 长会话观察项（hybrid 长上下文 MTP acceptance 或降）；AP 非确定性观察；L1-L6 位级电池待 PSReadLine 考古；nsys 普查与 P16 回归待启动。

## v8.3.1 补档（P2 门 + 认账112~115 + 生产指引）[R33]
- P2 门（parallel 2 双槽实并发稳定性）：PASS。判据全过：零 GGML_ASSERT/error/failed/crash；Start-Job 双客户端实并发 BOTH DONE；#29466 崩溃形状全踩（双槽交替 uid + LCP cache 复用 f_sim=1.000/f_keep=0.120 + graphs reused=1623）零崩；并发下单槽 tg=36.84 t/s 与单槽基线一致。结论：parallel 2 双槽（ST+skill 双应用）可上生产。档案=srv_p2gate.log。
- 夹具判读：A 空 content=thinking 吞尽 512 max_tokens（C1 reasoning=1831/finish=length；C2 enable_thinking=false 后 content=2463 非空）→ 服务器零缺陷。
- 生产指引：ST/skill 请求加 "chat_template_kwargs":{"enable_thinking":false} 或 max_tokens≥4096（thinking 常耗 500~2000 token 且计入预算）；bat 的 --no-mmap 下次更新换 --load-mode mmap；27B 生产 bat 维持 parallel 2（每槽 ctx=131072 已知悉）。
- 生产 bat 审计（R26）：与最新补丁对齐无需改；OMP_NUM_THREADS/OMP_WAIT_POLICY=no-op；A3B --rope-scale 1.0=no-op；A3B ubatch 4096 实测可行保留。
- 认账：112=命令参数存在性校验；113=PS 方法参数不可嵌管道；114=响应三字段完整性（finish/content/reasoning）；115=thinking token 计入 max_tokens。
- 挂账：#29466 评论（草稿 R29，贴后勾销）；X1 p-min 情报挖掘=新窗口开局；README v8.3 节。


---

<!-- ===== HANDOFF.md v8.4 增补段（追加于 v8.3.1 之后；前文未动，只增不删）===== -->

## 【v8.4】9. P22 spec-draft-p-min 战役档案（六臂全死；创作 MTP 永久关闭）

### 9.1 判决与数字
- 战役：--spec-draft-p-min 旗标 A/B（row 9/§3.4/挂账 X1 三方合流立项；零补丁零构建零重建，纯 server
  启动参数 A/B，全程零代码变更 tip=07a4a04）。
- 判决：**全臂判死，不采纳**。贪心 A1(0.75)=21.90 / A2(0.9)=22.81 / A3(n6,0.75)=20.95 vs A0=44.78
  （−49~−53%，全落带外低侧，胜线 46.12 无人触及）；创作 C1=19.70 / C2=20.43 vs C0=37.01（−47%/−45%）；
  长发同号（C1long=29.22 / C2long=27.24 vs C0long=37.15）→ row 9 判决树兑现：**创作 MTP 永久关闭**
  （p_min=0 时代双模型负实证 + p_min>0 重审判双确认，不再重开；符号冲突条款未触发）。
- 日常命令零变更：贪心/创作档均不设 p_min（维持现状）；README 无需变更（p-min 从未入 README 操作点）。
- 旗标活性已证（NC 臂）：p_min=1.0 → 32.73 落带 [31.0,34.5]（−26.9%）——首查即杀→恒极小形状、
  1.02 tok/步 = 等效无草稿地板。判死原因=机制在本机负收益，非旗标失效。

### 9.2 机理（对账推定，无 nsys）
- **剂量响应**：p_min=0→44.78（恒 3 草稿形状）｜0.75/0.9→21-23（中途早停→**批形状可变**）｜
  1.0→32.73（恒极小形状）。中间剂量低于两端=形状抖动税的唯一解释位。
- **超额时间**：A1 eval 11.57s vs 步数上限 256×31.4ms（NC 定标单价）=8.04s → ≥30% 墙钟为非正常步
  开销；graphs reused 250/256→39-47 崩塌。
- **归因**：主嫌疑=图形状抖动×重建税（pre-Volta 捕获反复发生；C1long/C2long U 形热身 18→28.6 t/s、
  tg_3s 尖峰 47-55=缓存冷热时序指纹）；共犯=草稿环逐 token 宿主同步。精确拆分需 nsys（维持降级）。
- **接受率-速度反位**：acceptance 0.547→0.82-0.97（过滤按宣示工作）但速度减半——p_min 优化错指标
  （省 verify 抵不过形状重建税）。
- **外部不可迁移**：博客 +69%（3090Ti 单卡、无图管线）vs 本机 −50%（4×P100 TP+图管线+wave1 宿主红利
  已压低基线）——认账⑬（跨平台外推须重测）教科书案例。
- **计数器铁律第六证**：NC 臂 acceptance=1.000 (2/2)、mean len=3.00 与 1.02 tok/步矛盾并存 →
  §5.3"计数器作废"升级为铁律（验收统计仅参考；判决只认速度差+MD5）。

### 9.3 md5 发散定性（首散点定位：合法 shape-effect，非真 bug）
- 锚：贪心 A0=NC=A2=A3=81c353a5b42644a058d329b0e5c1687c（位等）；创作 C0=9d1f91a6c558636c4aa780067b9f6928
  （新锚，穿罚链合法异于贪心锚）。
- 发散：A1=b7bcd09d69bb973d1914a3bb7d4b2435；C1=c86c00a7；C2=6f833827。
- 首散点：A0/A1 firstDiff=722 单 token 冠词翻转（a→the）后续逐字汇合；C0/C1、C0/C2 firstDiff=372
  单点短语分歧（East Asian 短语）后 C1/C2 同路重组（尾 len 差 17）。
- **定性：合法 shape-effect（早停改批形状→浮点归约踩罕见 argmax 边界）**。依据=单点分岔+语义等价
  替换+后续汇合（真 bug 预期=崩溃或持续漂移）；A2/A3 位等呈随机边界分布；发散仅存于已判死配置。
  **不开上游 issue（非上游 bug）**。
- b7bcd09d 与 P19 四指纹之首前 8 位相同：findstr 考古零命中且与 v8 §6 type 实文矛盾（工具行为未解，
  §9.6-117）；P19 指纹语义无档可考 → 记为巧合存疑，不影响判决（A1 已死无决策意义）。

### 9.4 副产品（正面增量）
1. **I:\ MTP 模型无草稿等效地板 ≈32.7 t/s**（NC 臂实测量）→ **本机 MTP 净收益 ≥+37%**（44.78/32.73），
   较 v5 时代 +10~13% 大幅放大——图解锁+wave1 宿主红利惠及 MTP（§7.1 机制又一证）；MTP 在贪心档
   的价值比历史认知更坚挺。
2. **UD 模型含 nextn 实锤**（C0 加载日志 unused tensor 列 blk.64.nextn.* 全家 + C1 draft 上下文创建
   成功）——记录缺口闭环。
3. **ggufinfo 脚本正常**（输出与 HANDOFF 量化组成记录吻合：UD=90.58% Q8_0+9.41% BF16 /
   MTP=99.99% Q8_0 / qwen35 / tensors=866）；此前"异常"实为 findstr 关键词误设（脚本输出为聚合统计
   格式，无 tensor 名单）。
4. golden.ps1 支持 -Mode/-NPred 参数（场外探针证实，工具能力入档）。

### 9.5 方法论增补（接 7.3）
- **NC 阴性对照先于收益臂**：旗标类战役先跑剂量极值探针（一臂三用：活性证明+地板测量+MTP 净收益
  测算），再谈收益臂。
- **MD5 门与图开关不可辨原理**：P12 位等证据成立 ⇒ golden MD5 永不能区分"旗标生效"vs"GRAPH_FORCE
  丢失"——速度成对差唯一 oracle 的又一维度；NC 臂+每窗口 env 回显必贴=强制反混杂（本役认账⑲零复发）。
- **"long 后 golden"顺序同构**：长发探针后紧接 golden（C0/C1/C2 同构）保证 md5 可比性。
- **预注册判读树自动执行**：六臂数据齐后判决零裁量，全程无人工干预争议。

### 9.6 认账增补（接 115）
- 116 NC1 落带后未先索取窗口 env 回显即判读（R5 识别返工一发 NCb 追平——正确动作但顺序应反转：
  环境证据先于数据解读）。
- 117 b7bcd09d 考古依赖 findstr 行为未先验证（零命中与 v8 §6 type 实文矛盾未解）；档案写作时应即注
  指纹定义，防后考古。
- 118 工具输出格式未验证即预注册 findstr 关键词（ggufinfo 输出为聚合统计无 tensor 名单）——认账⑱
  同族：先看真实输出再设断言。

### 9.7 勾销清单
- §3.4 "--spec-draft-p-min 创作档重审判"行 →【v8.4 判死】。
- §3.6 row 9 → 已判死（§9）。
- 挂账 "X1 p-min 情报挖掘=新窗口开局" → 已闭（本役收官）。
- 小挂账 "ggufinfo 脚本异常" → 已闭（§9.4-3，脚本无异常，关键词误设）。

<!-- ===== HANDOFF.md v8.4 增补段结束 ===== -->


<!-- ===== HANDOFF.md v8.4.1 勘误增补段（追加于 v8.4 之后；前文未动，只增不删）===== -->

## 【v8.4.1】9.8 勘误与认账 117 根因闭环（收官补档）

### 9.8.1 MTP 净收益口径勘误（§9.4-1）
- 原文"净收益 ≥+37%"方向不严谨，更正：**贪心档 MTP 净收益 ≈+37%，上界口径**
  （44.78/32.73−1=+36.8%；NC 臂=p_min=1.0 等效关草稿，若含微量草稿循环残开销/草稿 KV 常驻，
  真实净收益略低，合理区间 +30~37%）。定性不变：贪心档大幅正收益、创作档负收益。
- 增益归属注记：+37% vs v5 +10~13% 为跨口径不可直比（图前旧口径 vs 图后 server summarise；
  接受率内容相关）。候选解释=summarise 语料可预测性高推高接受率+graph/wave1 对 MTP 步宿主税
  削减；分解未经 nsys 不作定论。UD C0=37.01 与 I:\ 地板 32.73 为不同模型/提示词口径，互比无意义。

### 9.8.2 MTP 增益的负载条件性（判决总表）
| 场景 | MTP | 判决 |
|---|---|---|
| 贪心/精确档（I:\，temp0，无采样链，日常默认） | 开（p_min 不设） | ≈+37% 上界（A0/NC 同 prompt 成对实测）；贪心档最大单项功臣之一 |
| 省电档（I:\，3 卡） | 开 | 同贪心逻辑，未单独重测 |
| 创作/文学档（UD，全采样链，主场景） | 永久关闭 | p_min=0 时代双模型负 + p_min>0 本窗口 −45~−47%；a 劣势为创作档固有 |
| 任何配置 + --spec-draft-p-min | 全配置判死 | §9.2 形状抖动×图重建税 |
- 机理：MTP 每步产出 1+k·a，成本=verify 大 batch+草稿 forward；a 为唯一杠杆。p_min=0 下行有界
  （形状恒定，最坏趋近地板）；p_min>0 下行无界（形状可变→图缓存 miss，实测 −50%）。
  日常纪律：贪心档要么完整 MTP、要么彻底无草稿，永远不要中间剂量。
- 翻案通道：唯一未测组合=创作+MTP+p_min=0（现行栈），翻案成本=一个 batch 的 A/B；预期仍负
  （a 劣势固有+图前时代在摊销红利最大时已负），row 9 永久关闭维持。

### 9.8.3 认账 117 根因闭环 + 新纪律
- 117 已根因闭环（R7 findstr /n 实锤）：findstr 对 UTF-8 no-BOM 文件按 ANSI/GBK 解码；§6 行
  "：b7bcd09d"中全角冒号尾字节 9A 为 GBK 合法首字节，吞后随 'b'(0x62) 入双字节字符（控制台显示
  "锛歜7bcd09d"即铁证）→失配；efa2caeb 前导纯 ASCII→命中；745 行（v8.4 自身）前导 '='→命中；
  Batch-5 零命中=同机制。"FINDSTR: 写入错误"=控制台编码表面症状。
- 【新纪律，接 §2.3】UTF-8 文件检索一律 [System.IO.File]::ReadAllLines(path,[Text.Encoding]::UTF8)
  + Select-String -SimpleMatch；"findstr 未命中"不证明"不存在"（认账53 家族+1）。

<!-- ===== HANDOFF.md v8.4.1 勘误增补段结束 ===== -->
