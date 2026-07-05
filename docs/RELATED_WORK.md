# 相关工作与差异

检索日期：2026-07-06。检索范围包括 Mooncakes 索引中的 `wal`、`journal`、
`write-ahead log`、`redo log`、`crash recovery` 和 `crc32c`。

## trkbt10/vcdb

`vcdb` 是向量数据库，仓库说明中包含 WAL 持久化和分段管理。它的日志服务于向量
索引、属性和存储后端，是完整数据库的一部分。

MoonJournalKit 不实现向量数据库，也不依赖异步或文件系统包。它公开独立的记录
格式、事务恢复计划、可信截断边界和崩溃注入接口，可由 KV、队列、索引、编辑器
状态或其他存储项目复用。

参考：https://mooncakes.io/docs/trkbt10/vcdb

## mizchi/mnemo

`mnemo` 暴露 SQLite 写事务和 WAL checkpoint 配置，其持久性来自 SQLite。
MoonJournalKit 则实现自己的可移植日志帧和恢复状态机，不包装 SQLite。

参考：https://mooncakes.io/docs/mizchi/mnemo

## hustcer/fzip

`fzip` 为 GZIP/ZIP 数据实现标准 CRC-32（反射多项式 `0xEDB88320`），用途是压缩
格式校验。MoonJournalKit 使用 CRC32C Castagnoli（反射多项式 `0x82F63B78`），
并将其绑定到事务日志头部、载荷和崩溃恢复流程。

参考：https://mooncakes.io/docs/hustcer/fzip

## 项目定位

MoonJournalKit 的创新点不是“数据库里也有日志”，而是把过去散落在具体数据库
内部的日志帧、事务语义、损坏分类、检查点、分段和故障注入整理为 MoonBit 的
后端中立基础库，并给出跨后端可复现的安全证据。
