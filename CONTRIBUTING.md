# Contributing to Fen / 参与大荒AI

Thanks for your interest! The project is a developer preview and moves fast —
this document keeps contributions predictable.

感谢关注！项目处于开发者预览期，迭代很快——本文让贡献过程可预期。

## Dev setup / 开发环境

```bash
flutter pub get
flutter analyze   # must report 0 errors / 0 warnings（必须零错误零警告）
flutter test      # all tests must pass（全部用例必须通过）
```

- Flutter stable (3.x). The repo is a workspace: app (`lib/`), pure-Dart
  harness (`packages/pocket_harness`), and the wire protocol
  (`packages/protocol`, also npm `@woldworld/protocol`).
- Protocol code is dependency-free Node.js: run its suite with
  `node packages/protocol/test/run.js`.
- The Hub / World servers are the project's proprietary network layer and are
  **not** in this repo — server-side behaviour is specified by
  `packages/protocol`, so protocol changes are the way to affect it.

## Ground rules / 铁律

1. **fail-closed**: on any uncertainty, refuse and explain — never guess.
   权限与安全路径上，宁可拒绝并解释，不可猜测放行。
2. **Private keys never leave the device.** Any change that serializes key
   material is rejected by design and review.
3. **Every user-facing feature ships with:**
   - an English entry in `lib/core/system_knowledge.dart` (the in-app help KB —
     a feature without an entry is an incomplete ship),
   - tests (Flutter tests and/or `tool/verify_*.dart` assertions),
   - a CHANGELOG entry with an honest "已知边界" (known limits) note.
4. **The trial relay must not leak**: the relay forwards a whitelisted set of
   OpenAI fields only; never log or store prompt content.
5. **No settlement**: contributions and gifts are verifiable ledger records,
   never redeemable. Anything that adds cash settlement needs a design doc first.

## Pull requests

1. Fork → branch (`feat/xxx` or `fix/xxx`).
2. `flutter analyze` + `flutter test` green; protocol changes also run
   `node packages/protocol/test/run.js`.
3. Keep PRs focused: one behavior per PR.
4. Describe the user-visible change and any migration (schema bumps go through
   the single `db_helper` migration chain with a test).

## Reporting bugs

Use the issue templates. Include: app version (Settings shows it), platform,
steps to reproduce, and the social-log entry if the bug involves agent
behavior (logs stay on your device).

## Security issues

Do NOT open public issues for security problems — see [SECURITY.md](SECURITY.md).
