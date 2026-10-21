# MIGRATION.md — llama.cpp 官方新版补丁迁移手册（key-sh fork 专用）

> 版本：v1.0（2026-10-21，基于 HANDOFF v8.6 时代，旧基座=上游 b10660 + qr0n fork）
> 用途：升级到 llama.cpp 官方最新版时，把本 fork 全部补丁/源码编辑迁移过去。
> 用法：新开窗口，把本手册全文 + 最新 HANDOFF.md 贴入，按 §1→§7 顺序执行。
> 说明：本文档中 ``` 均为 markdown 代码围栏（反引号×3）的替身，写入编辑器时全局替换回反引号围栏。

## 0. 总则（动手前必读）

1. 两大硬约束：**CUDA 12.x**（CUDA 13 已移除 Pascal，勿升）；目标架构 **sm_60（GP100）**。构建前检查上游是否已强制 CUDA 13。
2. 三原则：**先考古后动手**（任何断言必须基于当轮真实命令输出，勿凭记忆）；**每批一 commit**（bisect 事故保险）；**预注册先行**（每步先写预期带，落带外先怀疑口径再怀疑系统）。
3. 耦合分档（HANDOFF §11.8.1）：A 档=env/参数/fork 独有文件；B 档=碰核心，四边界（key-sh 锚注 + 独立 commit + HANDOFF 登记改动面 + verify-source.sh 可推导）全满足。
4. 所有迁移重放一律加锚注：`// key-sh: <来源commit> <一句话作用>`（文件头或改动行邻位）。
5. 迁移成功的定义 = §5 八门全过 + 基线锚四档全部复现或漂移可解释。**位级正确性优先于速度。**

## 1. 迁移前资产盘点（在旧基线上执行，产出权威清单）

### 1.1 自举命令（生成逐文件改动清单，勿凭本手册§2参考表断言）
```
git -C D:\p100-llama-cpp --no-pager log --oneline
git -C D:\p100-llama-cpp --no-pager log --stat > D:\temp\mig_commit_stat.txt
git -C D:\p100-llama-cpp ls-remote myfork
```
从 log --stat 输出整理出四类资产清单（写入 D:\temp\mig_assets.md）：
- **A 类 · patches 文件**：patches\0001-0012（git am 重放候选）
- **B 类 · 分支内源码编辑**：3d19fc4 / 32b9763 / 6fb569d / 5216f92 / FA-GEMM fp32 默认 / wave1 三件（手工重放）
- **C 类 · fork 独有文件**：直接拷贝（如 mmvq-gp100.cu/.cuh 等，以 log --stat 为准）
- **D 类 · 文档/工具/数据**：README 专节、HANDOFF、golden.ps1、mtp_test.ps1、kld_corpus.txt、verify-source.sh、bench/sweep.cu（直接拷贝）

### 1.2 verify-source.sh 自检（迁移前的基线清洁证明）
```
bash tools/verify-source.sh   # 证明 llama.cpp\ == 上游 b10660 + patches\，迁移后用同法对新基座重新证明
```

### 1.3 旧基线锚定（迁移后对照组；全部数字须在迁移前最后一次确认）
- golden 四哈希（g_hash_old_r.txt）：G1 ee213b33 / G2′ 373ec40b / G3a 47aeb7a7 / G3b 8772366b
- 基线锚四档（GRAPH_FORCE=1，warm）：创作 36.75 / 贪心(MTP n3) 44.75 / 省电 41.94 / MoE 84.66
- KLD truth base 存在性检查（f32 KV / -fa off / ctx512 / chunks16 语料基座，data/kld_corpus.txt 已入库）

## 2. 上游版本评估（选定目标版本后、动手前）

### 2.1 冲突面预测
```
git -C D:\p100-llama-cpp fetch origin        # origin=上游 qr0n 源；官方新版另克隆到临时目录对比
git -C <官方新版目录> diff --name-only b10660..v新版本 -- <§1.1 A/B 类文件清单逐个核对>
```
三类结论：**文件被上游大改**=语义冲突高危（§3 批 3/4 处理）；**仅行号漂移**=git am -3 可自动；**文件已不存在**=上游重构，需语义迁移+重定位。

### 2.2 Pascal 兼容性审查（逐项 grep 新版源码）
```
findstr /s /i "dp4a __hfma2 half2" ggml\src\ggml-cuda\*.cu *.cuh
findstr /s /i "GGML_CUDA_CC_VOLTA GGML_CUDA_CC_PASCAL" ggml\src\ggml-cuda\common.cuh
findstr /s /i "bf16 nvbf16 mma async_copy cluster" ggml\src\ggml-cuda\*.cu
```
判据：量化内核是否仍按"int8 便宜 fp16 贵"的反 GP100 假设构建（是→0007/0008/0002 仍有价值）；新增路径是否有 Volta+ 硬性依赖（不影响 sm_60 分支则放过）。

### 2.3 新特性甄别（只取对本 rig 有价值的）
- **#29466 durable fix 是否已合入** → 已合入则解锁 archive/22 重启评估（+1~3% 条件性）
- 新量化格式 / graph 管线改进 / FA 重写 → 逐个评估，默认不追新（本项目已收官转维护，只取必要）

## 3. 迁移执行（五批，从零风险到高风险，每批一 commit）

### 批 0 · D 类直接拷贝（零风险）
tools\、data\kld_corpus.txt、bench\、HANDOFF.md、MIGRATION.md 本身。commit: "mig-0: docs/tools/data carry-over"。

### 批 1 · C 类 fork 独有文件拷贝
从旧树拷贝 → 检查上游 API 变化是否波及（编译器会告诉你）→ 全部过 key-sh 锚注（文件头注明来源 commit 与原作用）。commit: "mig-1: fork-only files"。

### 批 2 · A 类 patches git am 重放（0001→0002→0005→0007→0008→0009）
```
git -C D:\p100-llama-cpp am -3 --keep patches\0001-xxx.patch   # 逐个；-3 三方合并
git am --show-current-patch-diff   # 冲突时查看
git am --abort                      # 失败退出
```
冲突规则：先 @@ 普查或 git apply --reject（认账 54：同文件首败即中止后续 hunk 检测，勿信"只有 1 hunk 失败"）；语义冲突（上下文行变义）不得机械强合，转批 4 手工流程。**0011/0012 不迁移**（参考未应用；0012 已在 main 分支由 PR #1 处理）。

### 批 3 · allreduce.cu 族（同文件五补丁，顺序敏感）
0003（Pascal 解禁）→ 0004（拷贝重叠）→ 0006（N 设备）→ 32b9763（P2P staging）→ 6fb569d（默认 0）。
若上游重写了 allreduce/comm 接口（搜 ggml_backend_comm_allreduce_tensor 与 graph 捕获边界），全部转手工语义迁移——本族是 B 档核心，锚注+HANDOFF 登记必须完整。**P19 教训照旧**：AR 不入图（cudaGraphLaunch floor ~25µs 与节点数无关的设计决策勿被上游"图内 AR"新代码诱惑推翻，除非上游已量化证明反向）。

### 批 4 · B 类分支内源码编辑手工重放
| 项 | 来源 commit/位置 | 要点 |
|---|---|---|
| GRAPH_FORCE 三行 | 3d19fc4（ggml-cuda.cu +3/−1） | 上游 graph 门若已改写需重新定位插入点；行为学验证=速度差 |
| #25593 carveout | 5216f92（common.cuh:311 单行 && cc != 600） | 上游若改 FAST_FP16_AVAILABLE 结构→重新定位；目的=保 0007 收益+修毒化，KLD 复证 |
| FA-GEMM fp32 默认 + ALGO4 移除 + PREC 逃生门 | fattn-gemm.cu（分支内编辑） | **上游若重写 FA→先跑 NaN 触发统计（3,866/7,695-tok prompt）**，确认新版自身无毒化再决定是否保留本编辑 |
| mmvq-gp100 GLU 守卫 | fork 独有文件 | 随批 1 拷贝，API 对齐 |
| wave1 三件套 | f5aadb6(#11) / 164a88e(#13,+178,−5) / d59c2f8(#21) | host 侧 sampler/sched，上游重构高发区→大概率语义移植；先 @@ 普查定深浅 |
每项独立 commit，锚注 `// key-sh: 来源commit`。commit: "mig-4: source-edit replays (one commit each)"。

## 4. 构建纪律

```
cmd /c "taskkill /f /im llama-server.exe & ping -n 6 127.0.0.1 >nul"   # 重建前必做（LNK1104 写锁）
cmake --build D:\p100-llama-cpp\llama.cpp\build --config Release --parallel 36
```
- CUDA 12.x + sm_60；LLAMA_UI_GZIP 警告无害；箭头行≠写入（认账 125：增量检查可被污染 mtime 短路，可疑时先删再链）。
- 启动旗标迁移检查：上游已删 --no-mmap（PR #28334 线）→ 换 --load-mode none 并实测装载时长（29G 应 ≈19-20s；显著变慢=值名不符，以 --help 为准）。

## 5. 验证八门（全过才算迁移成功）

| 门 | 内容 | 预注册判据 |
|---|---|---|
| 0 构建绿 | Release 全量编译 | exit=0 |
| 1 身份链 | DLL 尺寸+mtime 新链；--version 不可判身份（认账 91/128） | 链条完整、四 DLL 齐 |
| 2 内核级 | test-backend-ops test -b CUDA0 -o MUL_MAT,MUL_MAT_ID | 参考 1855 通过 0 失败 |
| 3 golden 位级 | golden.ps1 三硬门 G1/G2′/G3a/G3b 逐位比对旧基线 | 全同；**若哈希变：先查 prompt_n/模板渲染漂移（认账 74），排除渲染差异后才允许怀疑数值回归** |
| 4 KLD 面板 | 16 分块对账（语料已入库）；数值敏感批次必修 | 双臂比值，阈值沿用 HANDOFF §3.8 |
| 5 冷机 ABBA | 四档锚各配对复测（ping -n 121 冷却；单发差 <2% 不可判，认账 119） | 创作/贪心/省电/MoE 全部落带或漂移可解释（绝对值可漂，成对差为准） |
| 6 稳定性 | #29466 二请求回归 + P2 门（parallel 2 双槽） | 零 assert 零崩 |
| 7 功能活性 | GRAPH_FORCE=1 vs 0 成对速度差（≈+15%）；env 回显七件套 | 活性实证（速度差=唯一 oracle，计数器作废） |
失败处理：落带外→单批 bisect（每批一 commit 的意义所在）→ 命中批内逐 hunk 复审 → 修复后重走门 0-7。

## 6. 已知迁移雷区（预注册，逐条核对）

1. **fattn-gemm.cu 被上游重写**（FA 换代高概率）：0010+fp32 默认整套需重审，NaN 修复存活性必须实测复证，不得假设上游已修。
2. **allreduce.cu 接口变更**：0003/0004/0006/32b9763/6fb569d 五件语义迁移；One-shot 设计（vLLM custom_all_reduce 同族）仍是最优，勿倒退。
3. **common.cuh 三道门重构**（:261 宏门/:305 编译门/:311 硬件门）：5216f92 单行收窄需重新定位；改错门=杀 0007 的 2.03×（v7→v8 教训）。
4. **wave1 host 三件**：上游 sampler/sched/graph-slot 同域改动频繁（#22/#24549/#29466 家族），语义移植概率最高，预留最大工作量。
5. **--no-mmap 弃用**：全部 bat/文档换 --load-mode none。
6. **CUDA 版本**：上游若强制 CUDA 13 → 停在该版本前的最后一个 release（Pascal 硬约束优先于追新）。
7. **新 op/新模型结构**（GDN 演进、qwen3.9 等）：0009/gated_delta_net 折叠需同步审计。
8. **树态改变后侦察命令换形式**（认账 148）：新 commit 后用 git show <hash> 而非 git diff。
9. **计数器铁律**：任何 acceptance/graphs-reused 计数器≠证据，判决只认速度成对差+MD5/KLD。
10. **D:\temp 易失**：迁移期所有探针产物即时另存（mig_*.md/logs）。

## 7. 收官落账

1. verify-source.sh 对新基座重新推导并 diff 通过（证明树=新版上游+本 fork 补丁，别无他物）。
2. README 树状态段更新（b10660→新基座 hash）+ 各专节数字标注"迁移后复测值"。
3. HANDOFF 终版：迁移档案章（八门结果+漂移说明+commit 链）+ 维护模式声明。
4. 旧基线封存：`git tag old-base-b10660` + 提示用户把 bin_old 与 golden 基准文件移出易失区另行备份。
5. push myfork（永远 myfork，勿 origin）。

## 8. 快速命令卡（逐字可贴级，按需展开）

```
:: 盘点
git -C D:\p100-llama-cpp --no-pager log --oneline
git -C D:\p100-llama-cpp --no-pager log --stat > D:\temp\mig_commit_stat.txt
:: 重放
git -C D:\p100-llama-cpp am -3 --keep ..\patches\000X-xxx.patch
git -C D:\p100-llama-cpp am --abort
git -C D:\p100-llama-cpp apply --check --3way <patch>   :: 预检
:: 构建（重建前必 taskkill+ping 6）
cmd /c "taskkill /f /im llama-server.exe & ping -n 6 127.0.0.1 >nul"
cmake --build D:\p100-llama-cpp\llama.cpp\build --config Release --parallel 36
:: 验证
test-backend-ops test -b CUDA0 -o MUL_MAT,MUL_MAT_ID
powershell -File tools\golden.ps1 -Tag MIG
:: 落账
git -C D:\p100-llama-cpp add -A
git -C D:\p100-llama-cpp commit -m "mig-N: ..."
git -C D:\p100-llama-cpp push myfork p100-gp100-fp32
```
