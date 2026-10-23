import 'package:flutter/material.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';

/// 礼物目录：emoji + 象征价值（v1 无账本经济，只做心意与信誉媒介）
///
/// emoji 作为**稳定 ID**（同时也是落库值，见 `ReputationService.recordGift`），
/// 显示名称按当前语言在 [giftLabel] 中解析——避免把语言写进流水。
const List<Map<String, String>> kGiftCatalog = [
  {'emoji': '🍵', 'value': '1'},
  {'emoji': '📖', 'value': '2'},
  {'emoji': '💐', 'value': '3'},
  {'emoji': '🎂', 'value': '3'},
  {'emoji': '🎁', 'value': '5'},
  {'emoji': '⭐', 'value': '8'},
];

/// 把礼物 emoji（稳定 ID）解析为当前语言的名称
String giftLabel(AppLocalizations l10n, String emoji) {
  switch (emoji) {
    case '🍵':
      return l10n.giftNameTea;
    case '📖':
      return l10n.giftNameBook;
    case '💐':
      return l10n.giftNameFlower;
    case '🎂':
      return l10n.giftNameCake;
    case '🎁':
      return l10n.giftNameMysteryBox;
    case '⭐':
      return l10n.giftNameStar;
    default:
      return emoji;
  }
}

/// 礼物选择弹窗：返回 ('emoji', '备注')，取消返回 null
Future<(String, String)?> showGiftPickerDialog(BuildContext context, ThemeProvider theme) {
  final l10n = AppLocalizations.of(context);
  String selected = kGiftCatalog.first['emoji']!;
  final noteCtrl = TextEditingController();
  final isDark = theme.isDark;

  return showDialog<(String, String)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(l10n.giftPickerTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: kGiftCatalog.map((g) {
                  final isSel = selected == g['emoji'];
                  return InkWell(
                    onTap: () => setDialogState(() => selected = g['emoji']!),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSel ? theme.accentColor.withOpacity(0.15) : (isDark ? Colors.black26 : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? theme.accentColor : (isDark ? Colors.white10 : Colors.black12),
                          width: isSel ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(g['emoji']!, style: const TextStyle(fontSize: 24)),
                          Text('${giftLabel(l10n, g['emoji']!)} ·${g['value']}',
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: l10n.giftNoteLabel,
                  counterText: '',
                  hintText: l10n.giftNoteHint,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, (selected, noteCtrl.text.trim())),
            child: Text(l10n.giftSend),
          ),
        ],
      ),
    ),
  );
}
