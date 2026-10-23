/// 主动社交成本预算：防止 LLM 自主搭讪烧钱刷屏。
class SocialBudget {
  /// 主动搭讪预算（防止 LLM 自主搭讪烧钱刷屏）。
  ///
  /// ★ 2026-09-29 用户指令：`perHourMax` 3 → **20**（原值在长期无人时为低于一次/20 分钟，
  /// 体感同样是"不活跃"）。
  /// ★ 同时把 `perDayMax` 20 → **200**：不提的话，新额度会在**第一个小时就被当天上限吃光**，
  ///   "每小时 20 次"这个改动**永远不会真正生效** —— 只改一半等于没改。
  ///   ⚠️ 代价记账：一次搭讪要 2–3 次 LLM 往返，满负荷约 **400–600 次调用/天**，
  ///   这是**成本开关**，不是安全阀（安全由 `_auditDraft` 与 PII 规则负责，两者互不替代）。
  SocialBudget({this.perHourMax = 20, this.perDayMax = 200});

  int perHourMax;
  int perDayMax;

  DateTime _hourStart = DateTime.now();
  DateTime _dayStart = DateTime.now();
  int _hourUsed = 0;
  int _dayUsed = 0;

  bool allow() {
    final now = DateTime.now();
    if (now.difference(_hourStart).inHours >= 1) {
      _hourStart = now;
      _hourUsed = 0;
    }
    if (now.difference(_dayStart).inDays >= 1) {
      _dayStart = now;
      _dayUsed = 0;
    }
    if (_hourUsed >= perHourMax || _dayUsed >= perDayMax) return false;
    _hourUsed++;
    _dayUsed++;
    return true;
  }

  int get remainingToday => perDayMax - _dayUsed;
}
