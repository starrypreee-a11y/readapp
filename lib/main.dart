import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReadingDiaryApp());
}

class ReadingDiaryApp extends StatelessWidget {
  const ReadingDiaryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '读书日记',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFc9a96e)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ========== 数据模型 ==========
class DiaryEntry {
  final String date;
  final String passage;
  final String note;
  final String source;

  DiaryEntry({
    required this.date,
    required this.passage,
    required this.note,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'passage': passage,
    'note': note,
    'source': source,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
    date: j['date'],
    passage: j['passage'],
    note: j['note'],
    source: j['source'],
  );
}

// ========== 存储 ==========
class Storage {
  static const _entriesKey = 'entries';
  static const _passagesKey = 'passages';

  static Future<List<DiaryEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => DiaryEntry.fromJson(e)).toList();
  }

  static Future<void> saveEntries(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_entriesKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  static Future<List<Map<String, String>>> loadPassages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_passagesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, String>.from(e)).toList();
  }

  static Future<void> savePassages(List<Map<String, String>> passages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passagesKey, jsonEncode(passages));
  }
}

// ========== 主页 ==========
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tab == 0 ? const ReadScreen() : const HistoryScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.book), label: '今日阅读'),
          NavigationDestination(icon: Icon(Icons.history), label: '历史记录'),
        ],
      ),
    );
  }
}

// ========== 阅读页 ==========
class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key});
  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  List<Map<String, String>> _passages = [];
  Map<String, String>? _current;
  final _noteCtrl = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final passages = await Storage.loadPassages();
    setState(() {
      _passages = passages;
      if (passages.isNotEmpty) {
        _current = passages[Random().nextInt(passages.length)];
      }
    });
  }

  void _random() {
    if (_passages.isEmpty) return;
    setState(() {
      _current = _passages[Random().nextInt(_passages.length)];
      _noteCtrl.clear();
      _saved = false;
    });
  }

  Future<void> _save() async {
    if (_current == null) return;
    final entries = await Storage.loadEntries();
    final today = DateTime.now().toString().substring(0, 10);
    entries.insert(0, DiaryEntry(
      date: today,
      passage: _current!['text'] ?? '',
      note: _noteCtrl.text,
      source: _current!['source'] ?? '',
    ));
    await Storage.saveEntries(entries);
    setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存到日记 ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日阅读'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddPassageScreen())
            ).then((_) => _load()),
          ),
        ],
      ),
      body: _passages.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('还没有文段，先添加一些吧', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddPassageScreen())
              ).then((_) => _load()),
              child: const Text('添加文段'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // 文段区域 80%
          Expanded(
            flex: 8,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_current?['source'] != null)
                        Text(
                          _current!['source']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _current?['text'] ?? '',
                            style: const TextStyle(fontSize: 17, height: 1.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.shuffle),
                            label: const Text('换一段'),
                            onPressed: _random,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 日记区域 20%
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _noteCtrl,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: '写点什么…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saved ? null : _save,
                      child: Text(_saved ? '已保存' : '保存到日记'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 添加文段页 ==========
class AddPassageScreen extends StatefulWidget {
  const AddPassageScreen({super.key});
  @override
  State<AddPassageScreen> createState() => _AddPassageScreenState();
}

class _AddPassageScreenState extends State<AddPassageScreen> {
  final _textCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();

  Future<void> _save() async {
    if (_textCtrl.text.trim().isEmpty) return;
    final passages = await Storage.loadPassages();
    passages.add({
      'text': _textCtrl.text.trim(),
      'source': _sourceCtrl.text.trim(),
    });
    await Storage.savePassages(passages);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加文段')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _sourceCtrl,
              decoration: const InputDecoration(
                labelText: '来源（书名/作者，可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  labelText: '文段内容',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 历史页 ==========
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DiaryEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await Storage.loadEntries();
    setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: _entries.isEmpty
          ? const Center(child: Text('还没有记录', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        itemCount: _entries.length,
        itemBuilder: (context, i) {
          final e = _entries[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ExpansionTile(
              title: Text(e.date, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(e.source, style: const TextStyle(fontSize: 12)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.passage, style: const TextStyle(fontSize: 15, height: 1.7)),
                      if (e.note.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text('📝 ${e.note}', style: const TextStyle(fontSize: 14, color: Colors.brown)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
