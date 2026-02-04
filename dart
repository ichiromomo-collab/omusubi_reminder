import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omusubi_reminder/main.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('おむすびリマインダー'), findsOneWidget);
  });
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeTabs(),
    );
  }
}


final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

Future<void> showTestNotification() async {
  const androidDetails = AndroidNotificationDetails(
    'test_channel',
    'テスト通知',
    channelDescription: '通知が出るか確認',
    importance: Importance.max,
    priority: Priority.high,
  );

  const details = NotificationDetails(android: androidDetails);

  await notifications.show(
    0,
    'おむすび通知テスト',
    '通知が出たら成功！',
    details,
  );
}



const String kGoogleApiKey = String.fromEnvironment('MAPS_API_KEY');

class PlacePrediction {
  final String description;
  final String placeId;
  PlacePrediction({required this.description, required this.placeId});
}

class PlacesApi {
  static Future<List<PlacePrediction>> autocomplete(String input) async {
    debugPrint('API KEY empty? = ${kGoogleApiKey.isEmpty}');

    if (kGoogleApiKey.isEmpty) return [];

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input,
        'key': kGoogleApiKey,
        'language': 'ja',
        'components': 'country:jp',
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final preds = (data['predictions'] as List?) ?? [];
    return preds.map((p) {
      final m = p as Map<String, dynamic>;
      return PlacePrediction(
        description: (m['description'] ?? '') as String,
        placeId: (m['place_id'] ?? '') as String,
      );
    }).where((x) => x.placeId.isNotEmpty).toList();
  }
}

/// =======================
/// Widget
/// =======================
Future<String?> showPlaceSearchDialog(BuildContext context) async {
  final c = TextEditingController();
  List<PlacePrediction> list = [];

  return showDialog<String>(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> search(String q) async {
            if (q.trim().length < 2) {
              setState(() => list = []);
              return;
            }
            final r = await PlacesApi.autocomplete(q.trim());
            setState(() => list = r);
          }

          return AlertDialog(
            title: const Text('住所を検索'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: c,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '施設名 / 住所の一部（例：浦添 ○○）',
                    ),
                    onChanged: search,
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const Text('2文字以上入れると候補が出るよ')
                  else
                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final p = list[i];
                          return ListTile(
                            title: Text(p.description),
                            onTap: () => Navigator.pop(context, p.description),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, c.text.trim()),
                child: const Text('手入力でOK'),
              ),
            ],
          );
        },
      );
    },
  );
}


/// =======================
/// Models
/// =======================


class Reminder {
  Reminder({required this.title, this.done = false});
  String title;
  bool done;
}

class MonthlyCheck {
  final String title;
  bool done;
  MonthlyCheck({required this.title, this.done = false});
}

class Patient {
  final String name;
  List<MonthlyCheck> checks;
  Patient({required this.name, required this.checks});
}

class Facility {
  final String id;
  String name;
  String address;

  Facility({
    required this.id,
    required this.name,
    this.address = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
      };

  static Facility fromJson(Map<String, dynamic> json) => Facility(
        id: json['id'] as String,
        name: (json['name'] ?? '') as String,
        address: (json['address'] ?? '') as String,
      );
}

/// =======================
/// Storage
/// =======================

class FacilityStore {
  static const _key = 'facilities_v2';

  static Future<List<Facility>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return [];

    final rawList = jsonDecode(s) as List<dynamic>;
    return rawList
        .map((e) => Facility.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
await initNotifications(); // あとで定義する
  runApp(const MyApp());



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
      MonthlyPage(), // 月初
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
          NavigationDestination(icon: Icon(Icons.location_on), label: '施設'),
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
  onPressed: showTestNotification,
  child: const Icon(Icons.notifications),
),

    );
  }
}

/// =======================
/// 月初（患者チェック）
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
  State<FacilityPage> createState() => FacilityPageState();
}

class FacilityPageState extends State<FacilityPage> {
  List<Facility> facilities = [];
  bool loading = true;
  String query = '';

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
    return result?.trim();
  }

  Future<void> addFacility() async {
    final name = await _inputDialog(
      title: '施設名を追加',
      hint: '例：◯◯老人ホーム / ◯◯病院',
    );
    if (!mounted) return;
    if (name == null || name.isEmpty) return;

    final address = await showPlaceSearchDialog(context);
    if (!mounted) return;
    if (address == null || address.trim().isEmpty) return;

    final f = Facility(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      address: address,
    );

    setState(() => facilities.insert(0, f));
    await _save();
  }

  Future<void> editFacility(Facility f) async {
    final name = await _inputDialog(title: '施設名を編集', initial: f.name);
    if (!mounted) return;
    if (name == null || name.isEmpty) return;

    final address =
        await _inputDialog(title: '住所を編集', initial: f.address, maxLines: 2);
    if (!mounted) return;
    if (address == null || address.isEmpty) return;

    setState(() {
      f.name = name;
      f.address = address;
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
    final filtered = facilities.where((f) {
      final q = query.trim();
      if (q.isEmpty) return true;
      return f.name.contains(q) || f.address.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('施設'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(loading ? '読み込み中…' : '登録 ${facilities.length} 件'),
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
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final f = filtered[i];
                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(f.name),
                        subtitle: f.address.trim().isEmpty ? null : Text(f.address),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => editFacility(f),
                        onLongPress: () => deleteFacility(i),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: addFacility, // ← 追加に戻すのが自然
        child: const Icon(Icons.add),
      ),
    );
  }
}
