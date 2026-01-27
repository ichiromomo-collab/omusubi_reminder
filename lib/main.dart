import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// =======================
/// Models
/// =======================

class Reminder {
  Reminder({required this.title, this.done = false});
  String title;
  bool done;
}

class Patient {
  final String name;
  List<MonthlyCheck> checks;
  Patient({required this.name, required this.checks});
}

class MonthlyCheck {
  final String title;
  bool done;
  MonthlyCheck({required this.title, this.done = false});
}

class Facility {
  final String id;
  String name;
  String note;

  Facility({
    required this.id,
    required this.name,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'note': note,
      };

  static Facility fromJson(Map<String, dynamic> json) => Facility(
        id: json['id'] as String,
        name: (json['name'] ?? '') as String,
        note: (json['note'] ?? '') as String,
      );
}

/// =======================
/// Storage
/// =======================

class FacilityStore {
  static const _key = 'facilities_v1';

  static Future<List<Facility>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return [];
    final list = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
    return list.map(Facility.fromJson).toList();
  }

  static Future<void> save(List<Facility> facilities) async {
    final prefs = await SharedPreferences.getInstance();
    final s = jsonEncode(facilities.map((f) => f.toJson()).toList());
    await prefs.setString(_key, s);
  }
}

/// =======================
/// App
/// =======================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: const HomeTabs(),
    );
  }
}

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});
  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      ReminderPage(), // 今日
      MonthlyPage(),  // 月初
      FacilityPage(), // 施設
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: '今日'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '月初'),
          NavigationDestination(icon: Icon(Icons.apartment), label: '施設'),
        ],
      ),
    );
  }
}

/// =======================
/// 今日（リマインダー）
/// =======================

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});
  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final List<Reminder> reminders = [];

  final List<String> templates = const [
    '鍵持った？',
    '物品（聴診器/パルス）確認',
    'スマホ充電OK？',
    '次の訪問先に連絡した？',
    '記録入力した？',
  ];

  Future<void> openAddDialog({String? preset}) async {
    final controller = TextEditingController(text: preset ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('リマインダー追加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例：鍵持った？'),
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    final title = (result ?? '').trim();
    if (title.isEmpty) return;

    setState(() => reminders.insert(0, Reminder(title: title)));
  }

  void toggleDone(int i) => setState(() => reminders[i].done = !reminders[i].done);

  Future<void> confirmDelete(int i) async {
    final target = reminders[i].title;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('「$target」を削除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('やめる')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    setState(() => reminders.removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = reminders.where((r) => r.done).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('おむすびリマインダー'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('合計 ${reminders.length} / 完了 $doneCount'),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ActionChip(
                label: Text(templates[i]),
                onPressed: () => openAddDialog(preset: templates[i]),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: reminders.isEmpty
                ? const Center(child: Text('＋で追加してね'))
                : ListView.builder(
                    itemCount: reminders.length,
                    itemBuilder: (_, i) {
                      final r = reminders[i];
                      return ListTile(
                        leading: Checkbox(value: r.done, onChanged: (_) => toggleDone(i)),
                        title: Text(
                          r.title,
                          style: TextStyle(decoration: r.done ? TextDecoration.lineThrough : null),
                        ),
                        onTap: () => toggleDone(i),
                        onLongPress: () => confirmDelete(i),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// =======================
/// 月初（患者チェック）
/// ※保存は後回し（今はUIだけ）
/// =======================

class MonthlyPage extends StatefulWidget {
  const MonthlyPage({super.key});
  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  final List<Patient> patients = [
    Patient(name: 'Aさん', checks: [MonthlyCheck(title: '保険証チェック'), MonthlyCheck(title: '医療証チェック')]),
    Patient(name: 'Bさん', checks: [MonthlyCheck(title: '保険証チェック')]),
  ];

  @override
  Widget build(BuildContext context) {
    final total = patients.fold<int>(0, (sum, p) => sum + p.checks.length);
    final done = patients.fold<int>(0, (sum, p) => sum + p.checks.where((c) => c.done).length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('月初チェック'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(alignment: Alignment.centerLeft, child: Text('合計 $total / 完了 $done')),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: patients.length,
        itemBuilder: (_, i) {
          final p = patients[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ExpansionTile(
              title: Text(p.name),
              children: [
                for (int j = 0; j < p.checks.length; j++)
                  CheckboxListTile(
                    title: Text(p.checks[j].title),
                    value: p.checks[j].done,
                    onChanged: (v) => setState(() => p.checks[j].done = v ?? false),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// =======================
/// 施設（一覧＋追加＋削除＋保存）
/// =======================

class FacilityPage extends StatefulWidget {
  const FacilityPage({super.key});
  @override
  State<FacilityPage> createState() => _FacilityPageState();
}

class _FacilityPageState extends State<FacilityPage> {
  List<Facility> facilities = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await FacilityStore.load();
    if (!mounted) return;
    setState(() {
      facilities = list;
      loading = false;
    });
  }

  Future<void> _save() async {
    await FacilityStore.save(facilities);
  }

  Future<String?> _inputDialog({
    required String title,
    String hint = '',
    String initial = '',
    int maxLines = 1,
  }) async {
    final c = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) => Navigator.pop(context, c.text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    return result?.trim();
  }

  Future<void> addFacility() async {
    final name = await _inputDialog(title: '施設を追加', hint: '例：◯◯老人ホーム / ◯◯病院');
    if (!mounted) return;
    if (name == null || name.isEmpty) return;

    final note = await _inputDialog(title: 'メモ（任意）', hint: '例：外鍵は玄関右のボックス', maxLines: 3);
    if (!mounted) return;

    final f = Facility(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      note: (note ?? ''),
    );

    setState(() => facilities.insert(0, f));
    await _save();
  }

  Future<void> editFacility(Facility f) async {
    final name = await _inputDialog(title: '施設名を編集', initial: f.name);
    if (!mounted) return;
    if (name == null || name.isEmpty) return;

    final note = await _inputDialog(title: 'メモを編集（任意）', initial: f.note, maxLines: 3);
    if (!mounted) return;

    setState(() {
      f.name = name;
      f.note = note ?? '';
    });
    await _save();
  }

  Future<void> deleteFacility(int index) async {
    final removed = facilities[index];

    setState(() => facilities.removeAt(index));
    await _save();

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${removed.name}」を削除しました'),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () async {
            setState(() => facilities.insert(index, removed));
            await _save();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施設'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                loading ? '読み込み中…' : '登録 ${facilities.length} 件',
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : facilities.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('まだ施設がないよ。\n右下の＋で追加しよ〜'),
                  ),
                )
              : ListView.builder(
                  itemCount: facilities.length,
                  itemBuilder: (_, i) {
                    final f = facilities[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(f.name),
                        subtitle: f.note.trim().isEmpty ? null : Text(f.note),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => editFacility(f),
                        onLongPress: () => deleteFacility(i),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: addFacility,
        child: const Icon(Icons.add),
      ),
    );
  }
}
