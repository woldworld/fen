# workmanager_android

[![pub package](https://img.shields.io/pub/v/workmanager_android.svg)](https://pub.dartlang.org/packages/workmanager_android)
[![pub points](https://img.shields.io/pub/points/workmanager_android)](https://pub.dev/packages/workmanager_android/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/fluttercommunity/flutter_workmanager/blob/main/LICENSE)

The Android implementation of [`workmanager`][workmanager].

## Description

This package provides the Android-specific implementation for the workmanager plugin, wrapping Android's WorkManager API to enable background task execution in Flutter applications.

## Usage

This package is [endorsed][federated_plugin_docs], which means you can simply use `workmanager`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package directly, you should add it to your `pubspec.yaml`:

```yaml
dependencies:
  workmanager_android: ^0.8.0
```

## Documentation

For detailed setup instructions, usage examples, and API documentation, please refer to the main [`workmanager`][workmanager] package documentation.

[workmanager]: https://pub.dartlang.org/packages/workmanager
[federated_plugin_docs]: https://flutter.dev/go/federated-plugins
---

## Local patches / 本仓对上游的改动

本目录是 `workmanager_android` **0.9.3** 的本地副本，用作 `dependency_overrides`
（见根 `pubspec.yaml`）。相对 pub.dev 上游，**只有一处改动**：

- `android/build.gradle:16` 强制 `apply plugin: 'kotlin-android'`。
  原因：本项目 `gradle.properties` 设 `android.builtInKotlin=false`（为兼容老插件），
  而 AGP 9 模板下上游在此条件下不再申明 kotlin-android，导致 Kotlin 源码不参与编译，
  报「找不到符号 WorkmanagerPlugin」。

**未改动**任何 Kotlin/Dart 源码、`AndroidManifest.xml` 或依赖声明；
上游 `LICENSE`（MIT）与版权声明原样保留。升级上游时只需重放这一行。
