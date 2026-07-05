# MoonJournalKit

面向 MoonBit 的事务预写日志（WAL）格式、崩溃恢复与校验基础库。

MoonJournalKit 不绑定文件系统、数据库或异步运行时。调用方负责持久化字节，
本库负责生成稳定记录、识别可信边界，并且只重放已经明确提交的事务。因此同一套
核心代码可以运行在 Wasm、Wasm GC、JavaScript 和 Native 后端。

## 主要能力

- 24 字节固定头部的 MWAL v1 二进制记录格式
- CRC32C（Castagnoli）逐记录完整性校验及增量接口
- `Begin / Put / Delete / Commit / Abort / Checkpoint` 事务语义
- 截断尾部、校验损坏、版本不支持、序列异常的精确区分
- 只重放已提交事务的确定性恢复计划
- 检查点裁剪、日志分段轮转、分段链连续性验证
- 稳定 JSON 诊断结果，便于 CI 和运维系统接入
- 逐字节断电切断和逐比特破坏的穷举验证

## 安装

```bash
moon add Sxy11112/moonjournalkit
```

## 快速示例

```moonbit nocheck
let records = [
  @journal.JournalRecord::new(Begin, 1U, 7U),
  @journal.JournalRecord::new(
    Put,
    2U,
    7U,
    payload=@journal.encode_put_payload(b"user/7", b"active"),
  ),
  @journal.JournalRecord::new(Commit, 3U, 7U),
]

let bytes = @journal.encode_records(records)
let scan = @journal.scan_journal(bytes)
let plan = @journal.build_recovery_plan(scan.records)
assert_eq(plan.actions.length(), 1)
```

发生断电时，应先用 `scan.valid_bytes` 截取可信前缀，再执行恢复计划。
缺失 `Commit` 的事务会出现在 `incomplete_transactions` 中，但不会进入
`actions`。

## 可复现验证

```bash
moon check --target all
moon test --target wasm
moon test --target wasm-gc
moon run cmd/main
moon run bench/main
```

当前测试覆盖标准 CRC32C 向量、二进制往返、损坏和截断、事务交错、检查点、
分段轮转以及崩溃注入。CLI 演示会输出四组 JSON 证据。基准工作负载包含
10,000 个事务、30,000 条记录，并对一个 100 事务样本检查所有字节切断点。

## 设计边界

本项目提供可嵌入的日志格式和恢复算法，不直接执行 `fsync`，也不替调用方决定
文件命名、目录布局、刷盘策略或并发模型。这样的边界既避免平台 API 污染，也让
浏览器持久化、对象存储、本地文件和自定义块设备能够共享同一恢复语义。

格式细节见 [docs/FORMAT.md](docs/FORMAT.md)，崩溃安全约束见
[docs/SAFETY.md](docs/SAFETY.md)，社区项目差异见
[docs/RELATED_WORK.md](docs/RELATED_WORK.md)。

许可证：Apache-2.0。
