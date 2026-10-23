# anchors/ —— 透明日志的 Merkle root 外部锚定记录

本目录存放 §16 透明日志的**外部锚定记录**：每一行是某一期的
`{"size": 叶子数, "root": Merkle 根(base58), "anchored_at": 毫秒时间戳}`。

- 只含**规模与根**，不含任何叶子或业务数据 —— 可安全公开。
- 由 `dart run tool/anchor_log.dart emit --hub <url>` 追加（**只追加，不删改**）。
- 每追加一次，把 `tool/anchor_log.dart` 打印的**锚定收据**粘进一个 **GitHub 签名提交**
  （或对该文件做 OpenTimestamps），锚定才真正生效。

完整机制、判据、第三方监督流程与诚实边界：见
[`lib/日志锚定与第三方监督.md`](../lib/日志锚定与第三方监督.md)。

校验：

```bash
dart run tool/anchor_log.dart verify --hub <hub-url>
```

⚠️ 本文件是**公开监督的基准**。任何删除/改写某一行的操作都会让整套机制失效，
因此 `anchor_log.dart` 刻意不提供 remove / rewrite 子命令。
