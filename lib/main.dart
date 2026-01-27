import 'package:flutter/material.dart';

class Patient {
  final String id;
  final String name;
  List<MonthlyCheck> checks;

  Patient({
    required this.id,
    required this.name,
    required this.checks,
  });
}

class MonthlyCheck {
  final String title;
  bool done;

  MonthlyCheck({
    required this.title,
    this.done = false,
  });
}

class Reminder {
  Reminder({required this.title, this.done = false});
  String title;
  bool done;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomeTabs(),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
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
    final pages = [
      const ReminderPage(), // 今日
      const MonthlyPage(), // 月初
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: '月初',
          ),
        ],
      ),
    );
  }
}

// -------------------- 月初チェック --------------------

class MonthlyPage extends StatefulWidget {
  const MonthlyPage({super.key});

  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  // 患者リスト（メモリ上）
  final List<Patient> patients = [
    Patient(
      id: 'a',
      name: 'Aさん',
      checks: [
        MonthlyCheck(title: '保険証チェック'),
        MonthlyCheck(title: '医療証チェック'),
      ],
    ),
    Patient(
      id: 'b',
      name: 'Bさん',
      checks: [
        MonthlyCheck(title: '保険証チェック'),
      ],
    ),
  ];

  // ★ 展開状態（患者ごとに覚える）
  final Map<String, bool> _expanded = {};

  Future<String?> _inputDialog({required String title, String hint = ''}) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) => Navigator.pop(context, c.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> addPatient() async {
    final name = await _inputDialog(title: '患者さんを追加', hint: '例：山田太郎さん / Aさん');
    if (name == null || name.isEmpty) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    setState(() {
      patients.insert(0, Patient(id: id, name: name, checks: []));
      _expanded[id] = true; // ★追加直後は開いてあげる
    });
  }

  Future<void> addCheckItem(Patient p) async {
    final title = await _inputDialog(title: '${p.name} のチェックを追加', hint: '例：保険証確認 / 限度額認定証');
    if (title == null || title.isEmpty) return;

    setState(() {
      p.checks.insert(0, MonthlyCheck(title: title));
      _expanded[p.id] = true; // ★追加したら開く
    });
  }

  Color _rateColor(double rate) {
    final cs = Theme.of(context).colorScheme;
    if (rate >= 1.0) return cs.tertiary;        // 100% 完了
    if (rate >= 0.5) return cs.primary;         // 半分以上
    if (rate > 0.0) return cs.secondary;        // ちょい進んでる
    return cs.outline;                           // 0%
  }

  double _patientRate(Patient p) {
    if (p.checks.isEmpty) return 0.0;
    final done = p.checks.where((c) => c.done).length;
    return done / p.checks.length;
  }

  Future<void> _deleteCheckWithConfirm(Patient p, int j) async {
    final title = p.checks[j].title;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('チェックを削除しますか？'),
        content: Text('「$title」を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      p.checks.removeAt(j);
    });
  }

  Future<void> _deletePatientWithUndo(int index) async {
    final p = patients[index];

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('患者さんを削除しますか？'),
        content: Text('「${p.name}」とチェック一覧を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      patients.removeAt(index);
      _expanded.remove(p.id);
    });

    // ★ スナックバーで「元に戻す」
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${p.name}」を削除しました'),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () {
            setState(() {
              patients.insert(index, p);
              _expanded[p.id] = true;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 上の「合計 / 完了」
    final total = patients.fold<int>(0, (sum, p) => sum + p.checks.length);
    final done = patients.fold<int>(0, (sum, p) => sum + p.checks.where((c) => c.done).length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('月初チェック'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('合計 $total / 完了 $done'),
            ),
          ),
        ),
      ),

      // ★空表示メッセージ（やさしく）
      body: patients.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'まだ患者さんがいないよ。\n右下の＋で追加してね 🍙',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, i) {
                final p = patients[i];

                final rate = _patientRate(p);
                final rateColor = _rateColor(rate);

                final remaining = p.checks.where((c) => !c.done).length;
                final isExpanded = _expanded[p.id] ?? false;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ExpansionTile(
                    initiallyExpanded: isExpanded,
                    onExpansionChanged: (v) => setState(() => _expanded[p.id] = v),

                    // ★患者長押しで削除（患者ごと）
                    title: GestureDetector(
                      onLongPress: () => _deletePatientWithUndo(i),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: rateColor), // ★完了率で色変える
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.name)),
                          const SizedBox(width: 8),
                          Text(
                            p.checks.isEmpty ? '—' : '${(rate * 100).round()}%',
                            style: TextStyle(color: rateColor),
                          ),
                        ],
                      ),
                    ),

                    trailing: IconButton(
                      tooltip: 'チェック追加',
                      icon: Icon(Icons.add_task, color: rateColor), // ★アイコン色も完了率で
                      onPressed: () => addCheckItem(p),
                    ),

                    children: [
                      // ★患者ごとの空表示メッセージ（やさしく）
                      if (p.checks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('まだチェックがないよ。右の＋で追加してね 😊'),
                        ),

                      for (int j = 0; j < p.checks.length; j++)
                        ListTile(
                          leading: Checkbox(
                            value: p.checks[j].done,
                            onChanged: (v) {
                              setState(() {
                                p.checks[j].done = v ?? false;

                                // ★「完了数が0になったら自動で折りたたむ」
                                final remainingNow = p.checks.where((c) => !c.done).length;
                                if (remainingNow == 0) {
                                  _expanded[p.id] = false;
                                }
                              });
                            },
                          ),
                          title: Text(p.checks[j].title),
                          onTap: () {
                            setState(() {
                              p.checks[j].done = !p.checks[j].done;

                              // ★同じく自動で折りたたむ
                              final remainingNow = p.checks.where((c) => !c.done).length;
                              if (remainingNow == 0) {
                                _expanded[p.id] = false;
                              }
                            });
                          },
                          onLongPress: () => _deleteCheckWithConfirm(p, j), // チェック削除
                        ),

                      if (p.checks.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            remaining == 0 ? '全部完了！おつかれさま 🍵' : '残り $remaining 件',
                            style: TextStyle(color: Theme.of(context).colorScheme.outline),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: addPatient,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// -------------------- 今日リマインダー --------------------

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
      builder: (context) {
        return AlertDialog(
          title: const Text('リマインダー追加'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '例：鍵持った？'),
            onSubmitted: (_) =>
                Navigator.pop(context, controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: const Text('追加'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    final title = result.trim();
    if (title.isEmpty) return;

    setState(() {
      reminders.insert(0, Reminder(title: title));
    });
  }

  void toggleDone(int index) {
    setState(() {
      reminders[index].done = !reminders[index].done;
    });
  }

  Future<void> confirmDelete(int index) async {
    final target = reminders[index].title;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('削除しますか？'),
          content: Text('「$target」を削除します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('やめる'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() {
      reminders.removeAt(index);
    });
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
              itemBuilder: (context, i) {
                return ActionChip(
                  label: Text(templates[i]),
                  onPressed: () => openAddDialog(preset: templates[i]),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: reminders.isEmpty
                ? const Center(child: Text('＋で追加してください'))
                : ListView.builder(
                    itemCount: reminders.length,
                    itemBuilder: (context, index) {
                      final r = reminders[index];
                      return ListTile(
                        leading: Checkbox(
                          value: r.done,
                          onChanged: (_) => toggleDone(index),
                        ),
                        title: Text(
                          r.title,
                          style: TextStyle(
                            decoration:
                                r.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        onTap: () => toggleDone(index),
                        onLongPress: () => confirmDelete(index),
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
