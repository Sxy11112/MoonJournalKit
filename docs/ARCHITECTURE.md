# 架构

MoonJournalKit 分为五层，各层均为纯 MoonBit 代码。

1. `checksum.mbt`：CRC32C 校验，不读取环境状态。
2. `codec.mbt`：单条 MWAL 记录的有界编解码。
3. `scanner.mbt`：在首个无效边界停止，返回可信字节数。
4. `recovery.mbt`：解释事务语义，生成确定性重放计划。
5. `segment.mbt` 与 `verification.mbt`：规划轮转并生成崩溃安全证据。

持久化适配器位于库边界之外。推荐调用顺序为：

`读取字节 -> scan_journal -> 截取 valid_bytes -> build_recovery_plan -> 重放 actions`

扫描器只判断字节级可信度；恢复器只处理已经通过扫描的记录。两者分离后，调用方
可以安全地记录物理损坏，同时继续分析此前的有效事务。

## 确定性

API 不读取系统时间、不生成随机数、不执行 I/O。相同字节和相同限制参数始终得到
相同的扫描结果、恢复动作、问题列表与 JSON 报告。这使崩溃案例能够跨后端复现。

## 资源边界

解码器在分配载荷前检查 `max_payload`，变更解码器在复制键之前检查 `max_key`，
扫描器用 `max_records` 限制记录数量。调用方可按部署环境收紧这些参数。
