import 'dart:convert';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';
import 'db_helper.dart';
import 'language_controller.dart';

class DreamService {
  static final DreamService _instance = DreamService._internal();
  factory DreamService() => _instance;
  DreamService._internal();

  Future<Agent?> _getDreamAgent() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key') ?? '';
    final baseUrlStr = prefs.getString('base_url') ?? 'https://api.deepseek.com';
    // 兜底必须是“当前可用”的模型名：deepseek-chat 已于 2026-07-24 停用，没填过
    // model_name 的用户会直接调用报错 ⇒ 与 agent_service.initAgent 的兜底保持一致
    final modelName = prefs.getString('model_name') ?? 'deepseek-v4-flash';

    if (apiKey.isEmpty) return null;
    return Agent.forProvider(OpenAIProvider(apiKey: apiKey, baseUrl: Uri.parse(baseUrlStr)), chatModelName: modelName);
  }

  Future<bool> triggerNightlyReflection() async {
    final agent = await _getDreamAgent();
    if (agent == null) return false;

    final recentMessages = await DBHelper.getMessages(limit: 50);
    if (recentMessages.isEmpty) return true; 

    String memoryFragments = "【近期记忆碎片】：\n";
    for (var msg in recentMessages.reversed) {
      final speaker = msg['isUser'] == 1 ? "主人" : "智能体";
      memoryFragments += "$speaker: ${msg['text']}\n";
    }

    final currentJob = await DBHelper.getProfile('job') ?? '';
    final currentHobbies = await DBHelper.getProfile('hobbies') ?? '';
    final currentDislikes = await DBHelper.getProfile('dislikes') ?? '';
    final currentOther = await DBHelper.getProfile('other_notes') ?? '';

    // 🚀 核心升级：Prompt 中要求 AI 提取“重复的指令”转化为技能 Skill
    final systemPrompt = """你是智能体的【潜意识反思中枢】(Dream Engine)。
你的任务是阅读主人近期的“记忆碎片”，提炼高价值长期记忆，并生成【自动化技能(Skills)】。

当前档案：
职业: $currentJob | 爱好: $currentHobbies | 忌讳: $currentDislikes | 其他: $currentOther

请分析记忆：
1. 提取新的爱好、忌讳、人物关系。
2. 🚀 寻找主人今天要求你做的“特殊规矩”或“重复性要求”（比如“以后叫我老板”、“每次回答必须分点”、“以后查天气默认查北京”等）。将这些转化为系统指令（Skills）。

【强制约束】：必须且只能输出合法的 JSON，不要 Markdown 包裹，格式如下：
{
  "job": "更新后的职业",
  "hobbies": "更新后的爱好",
  "dislikes": "更新后的忌讳",
  "other_notes": "其他细节",
  "new_people": [
    {"name": "名字", "relation": "关系", "identity": "身份", "notes": "备注"}
  ],
  "new_skills": [
    {"name": "skill_标识名_英文字母", "description": "这个技能解决什么问题", "content": "具体的提示词或规则命令"}
  ]
}
如果没有，数组为空 []。""";

    try {
      AppLogger.i('dream', '进入潜意识深度睡眠，开始记忆与技能提炼...');
      // machineSystem：产出是 JSON（记忆条目 + 技能），落库后喂回系统，
      // 不直接呈现给主人 —— 加“用日语回答”只会污染字段名与解析。
      final result = await agent.send(memoryFragments,
          history: [ChatMessage.system(machineSystem(systemPrompt))]);
      final rawOutput = result.output;
      
      final RegExp jsonRegExp = RegExp(r'\{[\s\S]*\}');
      final match = jsonRegExp.firstMatch(rawOutput);
      
      if (match != null) {
        final String jsonString = match.group(0)!;
        final Map<String, dynamic> memoryData = jsonDecode(jsonString);

        if (memoryData['job'] != null) await DBHelper.saveProfile('job', memoryData['job'].toString());
        if (memoryData['hobbies'] != null) await DBHelper.saveProfile('hobbies', memoryData['hobbies'].toString());
        if (memoryData['dislikes'] != null) await DBHelper.saveProfile('dislikes', memoryData['dislikes'].toString());
        if (memoryData['other_notes'] != null) await DBHelper.saveProfile('other_notes', memoryData['other_notes'].toString());

        if (memoryData['new_people'] != null && memoryData['new_people'] is List) {
          for (var person in memoryData['new_people']) {
            final name = person['name']?.toString() ?? '';
            if (name.isNotEmpty) {
              await DBHelper.insertRelationship(name, person['relation']?.toString() ?? '未知', person['identity']?.toString() ?? '', person['notes']?.toString() ?? '梦境提取');
            }
          }
        }

        // 🚀 自动技能注册：将大模型领悟出的新规矩，自动转化为 Skill 写入数据库工具箱！
        if (memoryData['new_skills'] != null && memoryData['new_skills'] is List) {
          for (var skill in memoryData['new_skills']) {
            final sName = skill['name']?.toString() ?? '';
            final sDesc = skill['description']?.toString() ?? '潜意识生成的自我进化技能';
            final sContent = skill['content']?.toString() ?? '';
            if (sName.isNotEmpty && sContent.isNotEmpty) {
              // 🔒 安全策略：梦境生成的技能默认禁用，用户确认后才启用
              await DBHelper.insertTool(sName, sDesc, 'skill', sContent, isFromDream: true);
            }
          }
        }

        AppLogger.i('dream', '苏醒！记忆库与行为技能已成功进化。');
        await DBHelper.insertMemoryEvent(
          eventType: 'dream_reflection',
          summary: '夜间记忆提炼完成，新增技能 ${(memoryData['new_skills'] as List?)?.length ?? 0} 个（默认禁用），档案已更新。',
        );
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.e('dream.reflection', e);
      return false;
    }
  }
}
