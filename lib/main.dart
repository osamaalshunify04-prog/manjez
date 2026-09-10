import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const ManjezApp());
}

class Task {
  String id;
  String title;
  String description;
  DateTime? dueDate;
  String priority;
  String category;
  bool completed;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.priority = 'متوسطة',
    this.category = 'عام',
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority,
        'category': category,
        'completed': completed,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'] ?? '',
        dueDate:
            json['dueDate'] == null ? null : DateTime.parse(json['dueDate']),
        priority: json['priority'] ?? 'متوسطة',
        category: json['category'] ?? 'عام',
        completed: json['completed'] ?? false,
      );
}

class ManjezApp extends StatefulWidget {
  const ManjezApp({super.key});

  @override
  State<ManjezApp> createState() => _ManjezAppState();
}

class _ManjezAppState extends State<ManjezApp> {
  ThemeMode themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'منجز',
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2563EB),
        brightness: Brightness.light,
        fontFamily: 'sans',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF60A5FA),
        brightness: Brightness.dark,
        fontFamily: 'sans',
      ),
      home: HomePage(
        themeMode: themeMode,
        onThemeChanged: (mode) => setState(() => themeMode = mode),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const HomePage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Task> tasks = [];
  final List<String> categories = ['عام', 'دراسة', 'عمل', 'شخصي', 'تسوق'];

  bool loading = true;
  String search = '';
  String selectedFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tasks');

    if (raw != null) {
      final list = jsonDecode(raw) as List;
      tasks.addAll(list.map((e) => Task.fromJson(e)));
    }

    setState(() => loading = false);
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'tasks',
      jsonEncode(tasks.map((e) => e.toJson()).toList()),
    );
  }

  List<Task> get visibleTasks {
    return tasks.where((task) {
      final matchesSearch =
          task.title.toLowerCase().contains(search.toLowerCase());

      final matchesFilter = selectedFilter == 'الكل' ||
          (selectedFilter == 'مكتملة' && task.completed) ||
          (selectedFilter == 'متبقية' && !task.completed);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  int get completedCount => tasks.where((e) => e.completed).length;

  double get progress =>
      tasks.isEmpty ? 0 : completedCount / tasks.length;

  Future<void> addTask() async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskEditor(categories: categories),
    );

    if (result != null) {
      setState(() => tasks.insert(0, result));
      await saveTasks();
    }
  }

  Future<void> editTask(Task task) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskEditor(
        categories: categories,
        existing: task,
      ),
    );

    if (result != null) {
      final index = tasks.indexWhere((e) => e.id == task.id);

      setState(() {
        if (index != -1) tasks[index] = result;
      });

      await saveTasks();
    }
  }

  Future<void> deleteTask(Task task) async {
    setState(() => tasks.removeWhere((e) => e.id == task.id));
    await saveTasks();
  }

  Future<void> toggleTask(Task task) async {
    setState(() => task.completed = !task.completed);
    await saveTasks();
  }

  void openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
          onClear: () async {
            tasks.clear();
            await saveTasks();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'منجز',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'الإعدادات',
              onPressed: openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: addTask,
          icon: const Icon(Icons.add),
          label: const Text('مهمة جديدة'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadTasks,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  children: [
                    _welcomeCard(theme),
                    const SizedBox(height: 18),
                    _searchBox(),
                    const SizedBox(height: 12),
                    _filters(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'مهامي',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${tasks.length} مهمة',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (visibleTasks.isEmpty)
                      _emptyState()
                    else
                      ...visibleTasks.map(_taskCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _welcomeCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أنجز يومك بثقة',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tasks.isEmpty
                ? 'ابدأ بإضافة أول مهمة لك'
                : 'لديك ${tasks.length - completedCount} مهام متبقية',
            style: TextStyle(
              color: theme.colorScheme.onPrimary.withOpacity(.9),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).round()}% مكتمل',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return TextField(
      onChanged: (value) => setState(() => search = value),
      decoration: InputDecoration(
        hintText: 'ابحث عن مهمة...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['الكل', 'متبقية', 'مكتملة'].map((filter) {
          final selected = selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: selected,
              onSelected: (_) =>
                  setState(() => selectedFilter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _taskCard(Task task) {
    Color priorityColor = task.priority == 'عالية'
        ? Colors.red
        : task.priority == 'منخفضة'
            ? Colors.green
            : Colors.orange;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 25),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => deleteTask(task),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          leading: Checkbox(
            value: task.completed,
            onChanged: (_) => toggleTask(task),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration:
                  task.completed ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.description.isNotEmpty)
                Text(
                  task.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                children: [
                  Chip(
                    label: Text(task.category),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(task.priority),
                    avatar: CircleAvatar(
                      backgroundColor: priorityColor,
                      radius: 5,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') editTask(task);
              if (value == 'delete') deleteTask(task);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('تعديل'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('حذف'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 55),
      child: Column(
        children: [
          Icon(
            Icons.task_alt,
            size: 70,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 15),
          const Text(
            'لا توجد مهام هنا',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 7),
          const Text('اضغط «مهمة جديدة» للبدء'),
        ],
      ),
    );
  }
}

class TaskEditor extends StatefulWidget {
  final List<String> categories;
  final Task? existing;

  const TaskEditor({
    super.key,
    required this.categories,
    this.existing,
  });

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late TextEditingController title;
  late TextEditingController description;
  late String priority;
  late String category;
  DateTime? date;

  @override
  void initState() {
    super.initState();

    title = TextEditingController(text: widget.existing?.title ?? '');
    description =
        TextEditingController(text: widget.existing?.description ?? '');

    priority = widget.existing?.priority ?? 'متوسطة';
    category = widget.existing?.category ?? widget.categories.first;
    date = widget.existing?.dueDate;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (result != null) {
      setState(() => date = result);
    }
  }

  void save() {
    if (title.text.trim().isEmpty) return;

    final task = Task(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.text.trim(),
      description: description.text.trim(),
      priority: priority,
      category: category,
      dueDate: date,
      completed: widget.existing?.completed ?? false,
    );

    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'إضافة مهمة' : 'تعديل المهمة',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم المهمة',
                  hintText: 'مثال: مذاكرة الرياضيات',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  hintText: 'تفاصيل إضافية اختيارية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(
                  labelText: 'الأولوية',
                  border: OutlineInputBorder(),
                ),
                items: ['منخفضة', 'متوسطة', 'عالية']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => priority = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'التصنيف',
                  border: OutlineInputBorder(),
                ),
                items: widget.categories
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => category = value!),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: chooseDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  date == null
                      ? 'اختيار تاريخ'
                      : '${date!.year}/${date!.month}/${date!.day}',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: save,
                icon: const Icon(Icons.check),
                label: Text(
                  widget.existing == null
                      ? 'إضافة المهمة'
                      : 'حفظ التعديلات',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onClear;

  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onClear,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ThemeMode mode;

  @override
  void initState() {
    super.initState();
    mode = widget.themeMode;
  }

  String get modeText {
    switch (mode) {
      case ThemeMode.light:
        return 'فاتح';
      case ThemeMode.dark:
        return 'داكن';
      case ThemeMode.system:
        return 'تلقائي';
    }
  }

  void chooseTheme() async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('تلقائي حسب النظام'),
                leading: const Icon(Icons.brightness_auto),
                onTap: () => Navigator.pop(context, ThemeMode.system),
              ),
              ListTile(
                title: const Text('الوضع الفاتح'),
                leading: const Icon(Icons.light_mode),
                onTap: () => Navigator.pop(context, ThemeMode.light),
              ),
              ListTile(
                title: const Text('الوضع الداكن'),
                leading: const Icon(Icons.dark_mode),
                onTap: () => Navigator.pop(context, ThemeMode.dark),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() => mode = selected);
      widget.onThemeChanged(selected);
    }
  }

  Future<void> clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف جميع المهام؟'),
        content: const Text(
          'سيتم حذف جميع المهام المحفوظة من الجهاز.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      widget.onClear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف جميع المهام')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'المظهر',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('مظهر التطبيق'),
                subtitle: Text(modeText),
                trailing: const Icon(Icons.chevron_left),
                onTap: chooseTheme,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'البيانات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('حذف جميع المهام'),
                subtitle: const Text('إزالة المهام المحفوظة من الجهاز'),
                onTap: clearAll,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('عن منجز'),
                subtitle: Text('تطبيق شامل لإدارة المهام اليومية'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
