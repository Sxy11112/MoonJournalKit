# Changelog

## 0.2.0 - 2026-07-18

- Added bounded `StreamJournalDecoder` for incremental chunk decoding without
  retaining previously emitted records.
- Added stream-tail, sequence-violation, and bounded-buffer tests.
- Updated executable package metadata, README, and OSC 2026 CI gates for the
  current MoonBit toolchain.

## 0.1.0 - 2026-07-06

- 定义 MWAL v1 固定头部和六类事务记录
- 实现 CRC32C、严格序列扫描和可信截断边界
- 实现提交、回滚、未完成事务和检查点恢复
- 增加日志分段轮转与链连续性校验
- 增加逐字节断电和逐比特破坏验证
- 提供稳定 JSON、CLI 示例和 10,000 事务基准
