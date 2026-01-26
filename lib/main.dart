import 'package:flutter/material.dart';

class Patient {
  final String name;
  List<MonthlyCheck> checks;

  Patient({
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

  // 月初：患者リスト（まずはメモリ上）
  final List<Patient> patients = [];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ReminderPage(), // 今日
      const MonthlyPage(),  // 月初
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

class MonthlyPage extends StatefulWidget {
  const MonthlyPage({super.key});

  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  // 仮データ（あとで追加できるようにする）
  final List<Patient> patients = [
    Patient(
      name: 'Aさん',
      checks: [
        MonthlyCheck(title: '保険証チェック'),
        MonthlyCheck(title: '医療証チェック'),
      ],
    ),
    Patient(
      name: 'Bさん',
      checks: [
        MonthlyCheck(title: '保険証チェック'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('月初チェック')),
      body: patients.isEmpty
          ? const Center(child: Text('患者さんがまだいないよ'))
          : ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, i) {
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
                          onChanged: (v) {
                            setState(() {
                              p.checks[j].done = v ?? false;
                            });
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}


class Reminder {
  Reminder({required this.title, this.done = false});
  String title;
  bool done;
}

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
              child: Text(
                '合計 ${reminders.length} / 完了 $doneCount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
                ? const Center(child: Text('＋で追加してね'))
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
                            decoration: r.done ? TextDecoration.lineThrough : null,
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
