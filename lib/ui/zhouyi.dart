import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

/// 周易引擎。
/// 数据已资产化（assets/data/zhouyi.json，不再编译进源码），
/// 使用时通过 [loadData] 惰性加载；未加载完成时 getAgua 返回占位提示。
class Zhouyi {
  // ==================== 64 卦二进制映射（保持内置，体积极小） ====================
  static Map<String, String> zyf = {
    "111111": "乾为天", "111110": "天风姤", "111100": "天山遁", "111000": "天地否", "110000": "风地观", "100000": "山地剥",
    "101000": "火地晋", "101111": "火天大有", "011011": "兑为泽", "011010": "泽水困", "011000": "泽地革", "011100": "泽山咸",
    "010100": "水山蹇", "000100": "地山谦", "001100": "雷山小过", "001011": "雷泽归妹", "101101": "离为火", "101100": "火山旅",
    "101110": "火风鼎", "101010": "火水未济", "100010": "山水蒙", "110010": "风水涣", "111010": "天水讼", "111101": "天火同人",
    "001001": "震为雷", "001000": "雷地豫", "001010": "雷水解", "001110": "雷风恒", "000110": "地风升", "010110": "水风井",
    "011110": "泽风大过", "011001": "泽雷随", "110110": "巽为风", "110111": "风天小畜", "110101": "风火家人", "110001": "风雷益",
    "111001": "天雷无妄", "101001": "火雷噬嗑", "100001": "山雷颐", "100110": "山风蛊", "010010": "坎为水", "010011": "水泽节",
    "010001": "水雷屯", "010101": "水火既济", "011101": "泽火革", "001101": "雷火丰", "000101": "地火明夷", "000010": "地水师",
    "100100": "艮为山", "100101": "山火贲", "100111": "山天大畜", "100011": "山泽损", "101011": "火泽睽", "111011": "天泽履",
    "110011": "风泽中孚", "110100": "风山渐", "000000": "坤为地", "000001": "地雷复", "000011": "地泽临", "000111": "地天泰",
    "001111": "雷天大壮", "011111": "泽天夬", "010111": "水天需", "010000": "水地比"
  };

  // ==================== 资产数据（惰性加载） ====================
  static List<Map<String, String>>? _orgText;
  static String _quanJie = '';

  static bool get isLoaded => _orgText != null && _orgText!.isNotEmpty;

  /// 从 assets/data/zhouyi.json 加载数据（幂等）
  static Future<void> loadData() async {
    if (_orgText != null) return;
    try {
      final raw = await rootBundle.loadString('assets/data/zhouyi.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _orgText = [
        for (final e in (data['orgText'] as List? ?? const []))
          Map<String, String>.from(e as Map),
      ];
      _quanJie = (data['quanJie'] as String?) ?? '';
    } catch (_) {
      _orgText = [];
    }
  }

  // ==================== 核心算法区 ====================

  static int _calculateC(int n) {
    final random = Random();
    int x = random.nextInt(n) + 1;
    int y = n - x;
    int a = x % 4;
    int b = (y - 1) % 4;
    if (a == 0) a = 4;
    if (b == 0) b = 4;
    return a + b + 1;
  }

  static List<String> _calculateYaoXiang() {
    int n = 50;
    int c1 = _calculateC(n - 1);
    n = n - c1;
    int c2 = _calculateC(n - 1);
    n = n - c2;
    int c3 = _calculateC(n - 1);
    int d = (49 - (c1 + c2 + c3)) ~/ 4;
    if (d == 6) return ['0', '6老阴', '变'];
    if (d == 7) return ['1', '7少阳', '静'];
    if (d == 8) return ['0', '8少阴', '静'];
    return ['1', '9老阳', '变'];
  }

  static String _calculatePosition(int n) {
    List<String> pos = ['第六爻', '第五爻', '第四爻', '第三爻', '第二爻', '第一爻'];
    return pos[n];
  }

  static List<List<String>> _calculateGuaxiangList() {
    List<List<String>> guaxiangone = [];
    for (int i = 0; i < 6; i++) {
      guaxiangone.add(_calculateYaoXiang());
    }
    return guaxiangone.reversed.toList();
  }

  static Map<String, String> _getOrgText(
      String guaming, {String? weizhi1, String? weizhi2}) {
    String guaci = "";
    String xiangci = "";
    String yaoci1 = "";
    String yaoci2 = "";
    final data = _orgText ?? const <Map<String, String>>[];

    for (var i in data) {
      if (i["卦名"] != null &&
          (i["卦名"]!.contains(guaming) || guaming.contains(i["卦名"]!))) {
        guaci = i["卦辞"] ?? "";
        xiangci = i["彖辞"] ?? "";
        if (weizhi1 != null) yaoci1 = i[weizhi1] ?? "";
        if (weizhi2 != null) yaoci2 = i[weizhi2] ?? "";
        break;
      }
    }
    return {"guaci": guaci, "xiangci": xiangci, "yaoci1": yaoci1, "yaoci2": yaoci2};
  }

  static String _getOrgTran(String guaming) {
    String t1 = '';
    if (_quanJie.isEmpty) return t1;
    List<String> text = _quanJie.split('###');
    for (int i = 1; i < text.length; i++) {
      List<String> lines = text[i].split('\n');
      if (lines.length > 1) {
        String name = lines[1].trim();
        if (guaming.contains(name) || name.contains(guaming)) {
          t1 = text[i];
          break;
        }
      }
    }
    return t1;
  }

  static Map<String, dynamic> _calculateGuaxiang() {
    List<List<String>> guaxianglist = _calculateGuaxiangList();
    String guaxiangStr = '';
    String bianguaxiangStr = '';
    List<String> bianshu = [];

    for (var i in guaxianglist) {
      guaxiangStr += i[0];
      if (i[2] == '变') {
        bianguaxiangStr += (i[0] == '0') ? '1' : '0';
      } else {
        bianguaxiangStr += i[0];
      }
      bianshu.add(i[2]);
    }

    String benguaming = zyf[guaxiangStr] ?? "【未知本卦】($guaxiangStr)";
    String bianguaming = zyf[bianguaxiangStr] ?? "【未知变卦】($bianguaxiangStr)";

    List<int> bianIndices = [];
    List<int> jingIndices = [];
    for (int i = 0; i < bianshu.length; i++) {
      if (bianshu[i] == '变') bianIndices.add(i);
      else jingIndices.add(i);
    }

    int n = bianIndices.length;
    String buci = '';
    List<String> buciwenti = [];
    List<String> shiguaming = [' ', ' '];

    if (n == 0) {
      var texts = _getOrgText(benguaming);
      String guaxiang = "${texts['guaci']}\n${texts['xiangci']}";
      buci = '无变爻，看本卦 [$benguaming] 的卦辞。\n本卦卦辞为:$guaxiang';
      String jieshi = _getOrgTran(benguaming);
      buciwenti.add('$jieshi。请根据上文内容：详细解读一下易经64卦中 [$benguaming]卦卦辞：[$guaxiang] 的含义！');
      shiguaming[0] = benguaming;
    } else if (n == 1) {
      String weizhi = _calculatePosition(bianIndices[0]);
      var texts = _getOrgText(benguaming, weizhi1: weizhi);
      String guaxiang = texts['yaoci1']!;
      buci = '一变爻，看本卦 [$benguaming] 的 [$weizhi] 的爻辞。\n本卦爻辞为:$guaxiang';
      String jieshi = _getOrgTran(benguaming);
      buciwenti.add('$jieshi。请根据上文内容：详细解读一下易经64卦中 [$benguaming]卦 的爻辞：[$guaxiang] 的含义！');
      shiguaming[0] = benguaming;
    } else if (n == 2) {
      String weizhi1 = _calculatePosition(bianIndices[0]);
      String weizhi2 = _calculatePosition(bianIndices[1]);
      var texts = _getOrgText(benguaming, weizhi1: weizhi1, weizhi2: weizhi2);
      String guaxiang = texts['yaoci1']!;
      buci = '二变爻，看本卦 [$benguaming] 的[$weizhi1、$weizhi2] 的爻辞，以上面 [$weizhi1] 的爻辞为主\n本卦爻辞为:$guaxiang';
      String jieshi = _getOrgTran(benguaming);
      buciwenti.add('$jieshi。请根据上文内容：详细解读一下易经64卦中 [$benguaming]卦 的爻辞：[$guaxiang] 的含义及哲理！');
      shiguaming[0] = benguaming;
    } else if (n == 3) {
      var texts1 = _getOrgText(benguaming);
      String guaxiang1 = "${texts1['guaci']}\n${texts1['xiangci']}";
      var texts2 = _getOrgText(bianguaming);
      String guaxiang2 = "${texts2['guaci']}\n${texts2['xiangci']}";
      buci = '三变爻，结合本卦 [$benguaming] 与变卦 [$bianguaming] 的卦辞一起看。\n本卦卦辞为:$guaxiang1\n变卦卦辞为:$guaxiang2';

      String jieshi1 = _getOrgTran(benguaming);
      String jieshi2 = _getOrgTran(bianguaming);
      buciwenti.add('$jieshi1。请根据上文内容：详细解读一下易经64卦中 [$benguaming]卦的卦辞: [$guaxiang1] 的含义及哲理！');
      buciwenti.add('$jieshi1,$jieshi2。请根据上文内容：详细阐述一下易经64卦中 [$benguaming]卦 的卦辞：[$guaxiang1] 及 [$bianguaming]卦 的卦辞：[$guaxiang2] 共同给我们的启发是什么？');
      shiguaming[0] = benguaming;
      shiguaming[1] = bianguaming;
    } else if (n == 4) {
      String weizhi1 = _calculatePosition(jingIndices[0]);
      String weizhi2 = _calculatePosition(jingIndices[1]);
      var texts = _getOrgText(bianguaming, weizhi1: weizhi1, weizhi2: weizhi2);
      String guaxiang = texts['yaoci2']!;
      buci = '四变爻，看变卦 [$bianguaming] 中未变化的[$weizhi1、$weizhi2] 的爻辞，以下面 [$weizhi2] 的爻辞为主。\n变卦爻辞为:$guaxiang';
      String jieshi = _getOrgTran(bianguaming);
      buciwenti.add('$jieshi。请根据上文内容：详细解读一下易经64卦中 [$bianguaming]卦 的爻辞：[$guaxiang] 的含义及哲理！');
      shiguaming[0] = bianguaming;
    } else if (n == 5) {
      String weizhi = _calculatePosition(jingIndices[0]);
      var texts = _getOrgText(bianguaming, weizhi1: weizhi);
      String guaxiang = texts['yaoci1']!;
      buci = '五变爻，看变卦 [$bianguaming] 中未变化的 [$weizhi] 的爻辞。\n变卦爻辞为:$guaxiang';
      String jieshi = _getOrgTran(bianguaming);
      buciwenti.add('$jieshi。请根据上文内容：详细解读一下易经64卦中 [$bianguaming]卦 的爻辞:[$guaxiang] 的含义及哲理！');
      shiguaming[0] = bianguaming;
    } else {
      var texts = _getOrgText(bianguaming);
      String guaxiang = "${texts['guaci']}\n${texts['xiangci']}";
      buci = '六变爻，看变卦 [$bianguaming] 的卦辞。\n变卦卦辞为:$guaxiang';
      String jieshi = _getOrgTran(bianguaming);
      buciwenti.add('$jieshi。请根据上文内容：详细解读一下易经64卦中 [$bianguaming]卦 卦辞: [$guaxiang] 的含义及哲理！');
      shiguaming[0] = bianguaming;
    }

    return {
      "benguaming": benguaming,
      "bianshu": bianshu,
      "bianguaming": bianguaming,
      "buci": buci,
      "buciwenti": buciwenti,
      "shiguaming": shiguaming
    };
  }

  /// 外部唯一调用的接口（数据未加载时先触发加载并返回占位提示）
  static List<String> getAgua() {
    if (!isLoaded) {
      unawaited(loadData());
      return ["卦象推演中…", "详解数据加载中，请稍后重新起卦。"];
    }
    var result = _calculateGuaxiang();
    String benguaming = result['benguaming'];
    List<String> bianshu = result['bianshu'];
    String bianguaming = result['bianguaming'];
    String buci = result['buci'];
    List<String> buciwenti = result['buciwenti'];

    String guaOutput = "您求得的卦名为：$benguaming卦，其中，各爻的变化分别为：[${bianshu.join('，')}]。\n"
        "此卦变化后的卦名为：$bianguaming。\n"
        "解卦提示：此卦$buci";

    String guayiOutput = "暂无解读";
    if (buciwenti.isNotEmpty) {
      guayiOutput = buciwenti[0].split("请根据上文内容：")[0];
    }

    return [guaOutput, guayiOutput];
  }
}
