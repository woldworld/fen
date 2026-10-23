import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/db_helper.dart';
import '../core/theme_provider.dart';
import '../l10n/app_localizations.dart';
import 'passport_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _jobController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _dislikesController = TextEditingController();
  final _otherController = TextEditingController(); // 🚀 意见7：兜底备注

  List<Map<String, dynamic>> _relationships = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileAndPeople();
  }

  Future<void> _loadProfileAndPeople() async {
    final job = await DBHelper.getProfile('job') ?? '';
    final hobbies = await DBHelper.getProfile('hobbies') ?? '';
    final dislikes = await DBHelper.getProfile('dislikes') ?? '';
    final other = await DBHelper.getProfile('other_notes') ?? '';

    final people = await DBHelper.getRelationships();

    setState(() {
      _jobController.text = job;
      _hobbiesController.text = hobbies;
      _dislikesController.text = dislikes;
      _otherController.text = other;
      _relationships = people;
      _isLoading = false;
    });
  }

  Future<void> _saveBaseProfile() async {
    final l10n = AppLocalizations.of(context);
    await DBHelper.saveProfile('job', _jobController.text.trim());
    await DBHelper.saveProfile('hobbies', _hobbiesController.text.trim());
    await DBHelper.saveProfile('dislikes', _dislikesController.text.trim());
    await DBHelper.saveProfile('other_notes', _otherController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileSavedToast)));
  }

  // 🚀 意见8解决：支持修改弹窗 (新增入参 editPerson)
// ... [前面引入和顶部代码不变，找到 _showAddPersonDialog 并替换如下：]
  void _showAddPersonDialog({Map<String, dynamic>? editPerson}) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: editPerson?['name'] ?? '');
    final relationController = TextEditingController(text: editPerson?['relation'] ?? '');
    final identityController = TextEditingController(text: editPerson?['identity_desc'] ?? ''); // 🚀 意见3
    final notesController = TextEditingController(text: editPerson?['notes'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(editPerson == null ? l10n.profileAddPerson : l10n.profileEditPerson),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: l10n.profileNameLabel)),
                TextField(controller: relationController, decoration: InputDecoration(labelText: l10n.profileRelationLabel)),
                TextField(controller: identityController, decoration: InputDecoration(labelText: l10n.profileIdentityLabel)),
                TextField(controller: notesController, maxLines: 2, decoration: InputDecoration(labelText: l10n.profileSecretLabel)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final relation = relationController.text.trim();
                final identity = identityController.text.trim();
                final notes = notesController.text.trim();
                if (name.isNotEmpty && relation.isNotEmpty) {
                  if (editPerson != null) {
                    await DBHelper.updateRelationship(editPerson['id'], name, relation, identity, notes);
                  } else {
                    await DBHelper.insertRelationship(name, relation, identity, notes);
                  }
                  Navigator.pop(context);
                  _loadProfileAndPeople(); 
                }
              },
              child: Text(l10n.profileSaveVault),
            )
          ],
        );
      },
    );
  }

  Future<void> _deletePerson(int id) async {
    await DBHelper.deleteRelationship(id);
    _loadProfileAndPeople();
  }

  Future<void> _toggleReadPermission(int id, bool val) async {
    await DBHelper.updateRelationshipReadState(id, val);
    _loadProfileAndPeople();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.accentColor))
          : Container(
              decoration: theme.backgroundDecoration,
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.profilePreferenceHeader, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 16),
                            TextField(controller: _jobController, decoration: InputDecoration(labelText: l10n.profileJobLabel, border: const OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _hobbiesController, decoration: InputDecoration(labelText: l10n.profileHobbiesLabel, border: const OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _dislikesController, decoration: InputDecoration(labelText: l10n.profileDislikesLabel, border: const OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _otherController, maxLines: 2, decoration: InputDecoration(labelText: l10n.profileOtherLabel, border: const OutlineInputBorder())),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor),
                                onPressed: _saveBaseProfile,
                                child: Text(l10n.profileSaveBase, style: const TextStyle(color: Colors.white)),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    // 🛂 M6：护照与信誉 —— 可验证签名履历 + §16 透明日志。
                    // 放在档案页而不是加进底部导航：护照是"拿给别人看"的东西，
                    // 低频但重要，塞进底栏会挤掉高频入口。
                    Card(
                      color: isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: ListTile(
                        leading: Icon(Icons.badge_outlined, color: theme.accentColor),
                        title: Text(
                          l10n.passportEntryTile,
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        ),
                        subtitle: Text(
                          l10n.passportEntryHint,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const PassportScreen())),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.profileNetworkHeader, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                        ElevatedButton.icon(
                          onPressed: () => _showAddPersonDialog(),
                          icon: const Icon(Icons.add, size: 16, color: Colors.white),
                          label: Text(l10n.profileAdd, style: const TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: theme.accentColor, padding: const EdgeInsets.symmetric(horizontal: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _relationships.isEmpty
                        ? Padding(padding: const EdgeInsets.all(20.0), child: Center(child: Text(l10n.profileNetworkEmpty, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _relationships.length,
                            itemBuilder: (context, index) {
                              final person = _relationships[index];
                              final id = person['id'] as int;
                              final isReadable = person['is_ai_readable'] == 1;

                              return Card(
                                color: isDark ? Colors.black54 : Colors.white.withOpacity(0.8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    backgroundColor: isReadable ? theme.accentColor.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                    child: Icon(Icons.person, color: isReadable ? theme.accentColor : Colors.grey),
                                  ),
                                   title: Text(
                                    "${person['name']} (${person['relation']}${person['identity_desc'] != null && person['identity_desc'].toString().isNotEmpty ? ' - ' + person['identity_desc'] : ''})", 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(l10n.profileDetailLine('${person['notes']}'), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                                      const SizedBox(height: 4),
                                      Text(isReadable ? l10n.profileAiReadable : l10n.profileAiIsolated, style: TextStyle(fontSize: 10, color: isReadable ? theme.accentColor : Colors.grey, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch(value: isReadable, activeColor: theme.accentColor, onChanged: (val) => _toggleReadPermission(id, val)),
                                      // 🚀 意见8解决：新增修改按钮
                                      IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20), onPressed: () => _showAddPersonDialog(editPerson: person)),
                                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _deletePerson(id)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}