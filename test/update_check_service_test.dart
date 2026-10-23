// 0.113.0 更新检查服务单测：纯逻辑（版本名比较 / 判定 / version.json 解析）。
//
// 为什么只测纯函数：HTTP 取数与 PackageInfo 依赖平台通道，宿主测试跑不了；
// 而「会不会把 0.112.0+1 → 0.113.0+1 判成已最新」这种**判定逻辑**恰恰是
// 本服务最容易错的地方（本仓 versionCode 长期停在 +1，只比 versionCode 必漏），
// 必须用单测钉死。网络/平台路径由 tool/verify_update_check.dart 守卫接线。
import 'package:flutter_test/flutter_test.dart';

import 'package:dahuang_ai/core/update_check_service.dart';

RemoteVersion _remote(String version, int code) => RemoteVersion(
      version: version,
      versionCode: code,
      url: 'https://wold.world/download/fen-$version-arm64.apk',
      bytes: 33366309,
      sha256: 'a' * 64,
      certSha256: 'b' * 64,
      scheme: 'v2',
    );

const _validJson = '''
{
  "app": "world.wold.fen",
  "version": "0.113.0+1",
  "versionCode": 1,
  "url": "https://wold.world/download/fen-0.113.0+1-arm64.apk",
  "bytes": 33366309,
  "sha256": "f7f3002e555c83f1811a51abd8a8ce6e7bdd909d606c5e12cfde22ed6252444a",
  "certSha256": "28e10ba026aa1b2ddd2ebf658173b271b1f5e0c804130289d666338e70d8de2e",
  "scheme": "v2"
}
''';

void main() {
  group('compareVersionNames（逐段数值化）', () {
    test('相等', () {
      expect(UpdateCheckService.compareVersionNames('0.112.0', '0.112.0'), 0);
      expect(UpdateCheckService.compareVersionNames('1.2.3+1', '1.2.3+9'), 0);
    });

    test('minor 更大 ⇒ 正', () {
      expect(UpdateCheckService.compareVersionNames('0.113.0', '0.112.0'), greaterThan(0));
      expect(UpdateCheckService.compareVersionNames('0.112.0', '0.113.0'), lessThan(0));
    });

    test('★ 关键：版本名不同但 versionCode 相同也必须判出新旧', () {
      // 本仓实证：0.110.0+1 → 0.112.0+1，versionCode 一直是 1。
      // 只比 versionCode 会把这次升级判成「已最新」——这是本单测存在的理由。
      // 注意参数序：compare(a, b) 是 a−b 语义（与 isNewer 里 remote 在前一致）。
      expect(UpdateCheckService.compareVersionNames('0.113.0+1', '0.112.0+1'),
          greaterThan(0));
      expect(UpdateCheckService.compareVersionNames('0.112.0+1', '0.113.0+1'),
          lessThan(0));
    });

    test('patch / major 段同样逐段比', () {
      expect(UpdateCheckService.compareVersionNames('0.112.1', '0.112.0'), greaterThan(0));
      expect(UpdateCheckService.compareVersionNames('1.0.0', '0.99.99'), greaterThan(0));
    });

    test('缺段按 0 计（1.2 == 1.2.0）', () {
      expect(UpdateCheckService.compareVersionNames('1.2', '1.2.0'), 0);
      expect(UpdateCheckService.compareVersionNames('1.2', '1.2.1'), lessThan(0));
    });

    test('非数字段按 0 计（不炸）', () {
      expect(UpdateCheckService.compareVersionNames('abc.1.0', '0.1.0'), 0);
    });
  });

  group('isNewer（判定）', () {
    test('版本名更新 ⇒ 有更新（versionCode 相同也认）', () {
      expect(
        UpdateCheckService.isNewer(
          localVersion: '0.112.0+1',
          localCode: 1,
          remote: _remote('0.113.0+1', 1),
        ),
        isTrue,
      );
    });

    test('版本名相同、versionCode 更高 ⇒ 有更新', () {
      expect(
        UpdateCheckService.isNewer(
          localVersion: '0.112.0+1',
          localCode: 1,
          remote: _remote('0.112.0+1', 2),
        ),
        isTrue,
      );
    });

    test('版本名相同、versionCode 相同 ⇒ 无更新', () {
      expect(
        UpdateCheckService.isNewer(
          localVersion: '0.112.0+1',
          localCode: 1,
          remote: _remote('0.112.0+1', 1),
        ),
        isFalse,
      );
    });

    test('远端更旧 ⇒ 无更新（不制造假升级提示）', () {
      expect(
        UpdateCheckService.isNewer(
          localVersion: '0.113.0+1',
          localCode: 1,
          remote: _remote('0.112.0+1', 1),
        ),
        isFalse,
      );
    });
  });

  group('parseVersionJson（坏数据必须抛，不许当成没有更新）', () {
    test('完整合法对象', () {
      final r = UpdateCheckService.parseVersionJson(_validJson);
      expect(r.version, '0.113.0+1');
      expect(r.versionCode, 1);
      expect(r.bytes, 33366309);
      expect(r.url, 'https://wold.world/download/fen-0.113.0+1-arm64.apk');
      expect(r.scheme, 'v2');
    });

    test('坏 JSON ⇒ FormatException', () {
      expect(() => UpdateCheckService.parseVersionJson('{not json'),
          throwsA(isA<FormatException>()));
    });

    test('不是对象 ⇒ FormatException', () {
      expect(() => UpdateCheckService.parseVersionJson('[1,2,3]'),
          throwsA(isA<FormatException>()));
    });

    test('缺字段 ⇒ FormatException', () {
      expect(() => UpdateCheckService.parseVersionJson('{"version":"1.0.0"}'),
          throwsA(isA<FormatException>()));
    });

    test('类型不对（bytes 是字符串）⇒ FormatException', () {
      final bad = _validJson.replaceAll('"bytes": 33366309', '"bytes": "33366309"');
      expect(() => UpdateCheckService.parseVersionJson(bad),
          throwsA(isA<FormatException>()));
    });

    test('url 非 https ⇒ FormatException', () {
      final bad = _validJson.replaceAll('https://wold.world', 'http://wold.world');
      expect(() => UpdateCheckService.parseVersionJson(bad),
          throwsA(isA<FormatException>()));
    });
  });
}
