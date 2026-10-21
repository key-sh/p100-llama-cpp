# tools/ 验证资产索引（2026-10-21 归档自 D:\temp 易失区）

目的：把调优战役中形成的高价值工件从易失区抢救入库，供日后考古与极限优化复用。
原则：原件原名不改；按功能分七个子目录；只收小体量难再生件；大体积原始数据不入库（见文末清单）。
既有工具（verify-source.sh / golden.ps1 / mtp_test.ps1 / ggufinfo.py / ggumeta.py / apply_nc.py.archived）原位不动。

## 目录一览（本次新增 84 件）
| 目录 | 件数 | 内容 |
|---|---|---|
| fixtures | 5 | 探针输入原件（golden/battery 之活输入） |
| reference | 50 | 哈希基线、golden 原件、拓扑/崩溃/KLD 证据、nsys 分析摘要、旧构建旗标面 |
| harness | 12 | 可复用测量脚本 |
| mining | 5 | nsys 挖矿脚本与捕获命令记录 |
| probes | 3 | CUDA 微探针源码 |
| surgery | 6 | 源码变体手术脚本 |
| forensics | 3 | P0 exe 损坏事故取证 |

## fixtures/（逐字复制纪律适用：改一字即破基线）
- longprompt.txt —— 创作档长探针正文原件
- req_creat_v2.json / req_creat_v3.json —— 创作档探针请求（两版）
- t285.txt / req_t285.json —— 285-token 提示词及请求 JSON（G3 族）

## reference/
- g_hash_old_r.txt —— golden 四哈希权威基线（G1/G2'/G3a/G3b；MIGRATION §1.3 引用件）；g_hash_new_r.txt 为对照臂；g_hash_old/new.txt 为前身
- golden_old_r.txt / golden_new_r.txt —— R17 重锚 golden 输出对
- golden_G2r.txt —— G2' 首锚时代原始输出
- g1~g3b_old/new.json（8 件）—— R17 golden 四探针 API 响应对
- r12_G1~G4_sw0/sw1_content.txt（8 件）—— R12 全量 golden 各臂原始输出
- nvsmi_r1.txt —— GPU 拓扑快照（GPU0 归 CPU1、跨 UPI 结论的原始证据）
- srv_r_new.crash.log + bcj_assert_context.txt —— #29466 崩溃取证原件（issue 评论中提及的日志即此）
- k3b_truth.log / k4a_buggy_kld.log / k4b_new_kld.log —— KLD 门 truth 与 buggy/fixed 对照
- p16_smoke_result.txt / p16smoke.log / p16smoke.err.log —— P16 收官冒烟终值（tg=36.57）与服务器横幅
- srv_help_r1.txt / cli_help.txt / bench_help.txt / srv_ver_r1.txt —— 旧构建旗标面与版本快照（迁移旗标审计对照面，如 --no-mmap 到 --load-mode none）
- p07_perf.txt / p07_sm.csv / p07_soak_tg.csv / p07_pwr.csv —— P07 功耗/频率/soak 数据（decode 无节流结论依据）
- d1_*/d2_*（7 件）—— AR 时间分解与层画像 nsys 分析摘要（入队/自旋结论依据）
- p16floor_stats.txt / p16floor_h2.log / p16node_h4.log —— P16 地板与节点级分析摘要

## harness/（复用模板；内部绝对路径指向 D:\temp 与当时构建树，复用前先改）
- p16_launch.bat —— 标准启动器（全套 env 旗标；收官冒烟即用此直启）
- p16_sw.bat —— A/B 臂切换器（P16 判死后退役，留作方法论）
- p16_smoke.ps1 —— 冒烟模板（健康轮询 + finally 清理）
- r13_abba.ps1 —— 冷机 ABBA 配对测量模板（判读纪律：单发差 <2% 不可判）
- r12_collect.ps1 / r12_judge.ps1 —— golden 采集与 MD5 判读
- r5_reads.ps1 / r6_reads.ps1 —— 冷机多读
- p16_probe_run.ps1 / p16_v2_run.ps1 —— A/B 探针运行器
- p07_analyze.ps1 / p07_reanalyze.ps1 —— 功耗/soak 分析

## mining/
- p16_trace_mine.ps1 / p16_mine2.ps1 —— nsys 挖矿脚本（内核忙时/AR 占比等方法论）
- p16floor/p16greedy/p16node_cli.log —— nsys 捕获命令行原件（复现捕获用）

## probes/（源码，需 nvcc -arch=sm_60 重编译）
- p2p_probe.cu —— P2P 拓扑探针
- p19b_spike.cu —— launch 地板 spike（22µs 入队结论来源）
- p19hello.cu —— CUDA 编译冒烟模板

## surgery/（方法论存档，行号已随源码演进失效）
- p19a.py / p19b.py / p19c.py / p19fix.py / p20fix.py —— P19/P20 源码程序化变体编辑脚本
- ttype30.py —— GGUF 张量类型统计（bf16 占比分析）

## forensics/
- exe_forensics.ps1 —— P0 exe 损坏取证脚本
- damaged_llama-server_20261020_1010.exe / stray_cls_20261020_1010.bin —— P0 事故残骸原件

## 未入库大件（留在 D:\temp——易失！建议另行非易失备份）
- nsys 原始库：cli_ar1-4 / cli_graph / cli_map / d1_ar1 / d1_ar2 / d1_ar2_n256 / d2_layer1 / p16floor / p16greedy / p16node 的 .nsys-rep（.sqlite 可由 nsys export 再生，可不备）
- trace 导出 CSV：trace1/3/4/G/M、p16floor、p16node 的 _cuda_gpu_trace.csv
- 旧二进制目录：bin_old / r26bin_old / r28bin_base / sbp
- 超大 build log：k3/k4 三件（各 52MB）、p16build2.log、p16final_build.log
- srv_p07_soak.log（334KB；蒸馏数据已入库 p07_soak_tg.csv）
最简备份：robocopy D:\temp 目标盘:\p100_temp_backup /E /R:1 /W:1

## 复用注意
1. 本索引只做导航，文件与战役的精确对应以 HANDOFF 各章记录为准；
2. fixtures/ 受"标准模板逐字复制"纪律保护；
3. 脚本重跑前先核内部路径与当前构建树是否一致。