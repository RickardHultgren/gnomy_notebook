import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

const _ink = Color(0xFF25342D);
const _paper = Color(0xFFF5F3ED);
const _moss = Color(0xFF647C67);
const _symbolPalette = <String, int>{
  'Moss': 0xFF647C67,
  'Sky': 0xFF607A8A,
  'Lantern': 0xFFCC9558,
  'Berry': 0xFF9B6670,
  'Heather': 0xFF7B7096,
};

class GnomyNotebookApp extends StatelessWidget {
  const GnomyNotebookApp({super.key, required this.store});
  final NotebookStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gnomy Phenomenon Notebook',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _moss, surface: _paper),
          scaffoldBackgroundColor: _paper,
          appBarTheme: const AppBarTheme(backgroundColor: _paper, foregroundColor: _ink),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        home: NotebookShell(store: store),
      );
}

class NotebookShell extends StatefulWidget {
  const NotebookShell({super.key, required this.store});
  final NotebookStore store;

  @override
  State<NotebookShell> createState() => _NotebookShellState();
}

class _NotebookShellState extends State<NotebookShell> with WidgetsBindingObserver {
  int _section = 0;
  String? _workspaceId;
  NotebookStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(store.flush());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (!store.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (store.loadError != null) return StorageRecoveryScreen(store: store);
        final workspace = _workspaceId == null ? null : _findWorkspace(_workspaceId!);
        final title = workspace?.title ?? const ['Notebook', 'Phenomenon map', 'Symbols', 'Sources', 'Settings'][_section];
        return LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final destinations = const [
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Notebook'),
            NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Map'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Symbols'),
            NavigationDestination(icon: Icon(Icons.bookmarks_outlined), selectedIcon: Icon(Icons.bookmarks), label: 'Sources'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
          ];
          final selected = workspace == null ? _section : 0;
          return Scaffold(
            appBar: AppBar(
              leading: workspace == null
                  ? null
                  : IconButton(tooltip: 'Back to notebook', onPressed: () => setState(() => _workspaceId = null), icon: const Icon(Icons.arrow_back)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                if (store.saveFailed)
                  const Padding(padding: EdgeInsets.only(right: 18), child: Tooltip(message: 'Could not save. Export a copy before closing.', child: Icon(Icons.cloud_off_outlined, color: Colors.red))),
                if (store.savePending && !store.saveFailed)
                  const Padding(padding: EdgeInsets.only(right: 18), child: Tooltip(message: 'Saving changes…', child: Icon(Icons.sync, size: 20))),
                if (workspace != null)
                  PopupMenuButton<String>(
                    tooltip: 'Workspace actions',
                    onSelected: (action) async {
                      if (action == 'rename') await _editWorkspace(context, store, workspace);
                      if (action == 'delete') {
                        final deleted = await _confirmDeleteWorkspace(context, workspace);
                        if (deleted) {
                          await store.deleteWorkspace(workspace.id);
                          if (mounted) setState(() => _workspaceId = null);
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Edit title and question')),
                      PopupMenuItem(value: 'delete', child: Text('Delete workspace')),
                    ],
                  ),
                const Padding(padding: EdgeInsets.only(right: 16), child: Center(child: _DemoBadge())),
              ],
            ),
            body: Column(children: [
              if (store.saveFailed)
                MaterialBanner(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  content: const Text('Browser storage could not save this notebook. Export a backup from Settings before closing.'),
                  actions: [TextButton(onPressed: () => setState(() { _section = 4; _workspaceId = null; }), child: const Text('OPEN SETTINGS'))],
                ),
              Expanded(
                child: Row(children: [
                  if (wide)
                    NavigationRail(
                      selectedIndex: selected,
                      onDestinationSelected: (value) => setState(() { _section = value; _workspaceId = null; }),
                      labelType: NavigationRailLabelType.all,
                      destinations: destinations.map((item) => NavigationRailDestination(icon: item.icon, selectedIcon: item.selectedIcon, label: Text(item.label))).toList(),
                    ),
                  Expanded(child: _content(workspace)),
                ]),
              ),
            ]),
            bottomNavigationBar: wide || workspace != null
                ? null
                : NavigationBar(
                    selectedIndex: _section,
                    onDestinationSelected: (value) => setState(() => _section = value),
                    destinations: destinations,
                  ),
          );
        });
      },
    );
  }

  Widget _content(PhenomenonWorkspace? workspace) {
    if (workspace != null) return WorkspacePage(store: store, workspace: workspace);
    switch (_section) {
      case 1: return MapPage(store: store, onOpen: (id) => setState(() { _workspaceId = id; _section = 0; }));
      case 2: return SymbolsPage(store: store);
      case 3: return SourcesPage(store: store);
      case 4: return SettingsPage(store: store);
      default: return HomePage(store: store, onOpen: (id) => setState(() => _workspaceId = id));
    }
  }

  PhenomenonWorkspace? _findWorkspace(String id) {
    for (final workspace in store.data.workspaces) {
      if (workspace.id == id) return workspace;
    }
    _workspaceId = null;
    return null;
  }
}

Future<void> _editWorkspace(BuildContext context, NotebookStore store, PhenomenonWorkspace workspace) async {
  final title = TextEditingController(text: workspace.title);
  final question = TextEditingController(text: workspace.question);
  final save = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit phenomenon'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: question, maxLines: 2, decoration: const InputDecoration(labelText: 'Question')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    ),
  );
  if (save == true && title.text.trim().isNotEmpty) {
    workspace.title = title.text;
    workspace.question = question.text;
    await store.updateWorkspace(workspace);
  }
  title.dispose();
  question.dispose();
}

Future<bool> _confirmDeleteWorkspace(BuildContext context, PhenomenonWorkspace workspace) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete workspace?'),
          content: Text('“${workspace.title}” and its diary, notes, and writing will be permanently deleted.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        ),
      ) ??
      false;
}

class StorageRecoveryScreen extends StatelessWidget {
  const StorageRecoveryScreen({super.key, required this.store});
  final NotebookStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notebook storage')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
              const Icon(Icons.warning_amber_rounded, size: 44, color: Color(0xFF9A633B)),
              const SizedBox(height: 12),
              Text(store.loadError ?? 'Notebook data could not be loaded.', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text('The app has not replaced the stored notebook. If the stored text is available, copy it before choosing to start over.'),
              const SizedBox(height: 18),
              if (store.unreadableData != null)
                OutlinedButton.icon(onPressed: () => _showStoredText(context), icon: const Icon(Icons.data_object), label: const Text('View stored text')),
              OutlinedButton.icon(onPressed: () => SettingsPage(store: store)._showImport(context), icon: const Icon(Icons.file_open_outlined), label: const Text('Import a JSON backup')),
              OutlinedButton.icon(onPressed: store.retryLoad, icon: const Icon(Icons.refresh), label: const Text('Try loading again')),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(onPressed: () => _startOver(context), icon: const Icon(Icons.restart_alt), label: const Text('Replace with a demo notebook')),
              if (store.saveFailed) const Padding(padding: EdgeInsets.only(top: 14), child: Text('Browser storage is still unavailable. Changes may not be saved.', style: TextStyle(color: Colors.red))),
            ]),
          ),
        ),
      );

  void _showStoredText(BuildContext context) {
    final raw = store.unreadableData;
    if (raw == null) return;
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Stored notebook text'),
      content: SizedBox(width: 680, child: SingleChildScrollView(child: SelectableText(raw, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }

  Future<void> _startOver(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Replace stored notebook?'),
      content: const Text('This replaces the current saved data with demo content. Copy the stored text first if you may need it.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Replace data'))],
    ));
    if (confirmed == true) await store.replaceUnreadableDataWithDemo();
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFE9E4D6), borderRadius: BorderRadius.circular(30)),
        child: const Text('LOCAL ONLY', style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700)),
      );
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.maxWidth = 980});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store, required this.onOpen});
  final NotebookStore store;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => PageFrame(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 18, 24, 40), children: [
          const Text('A place to look again.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 8),
          Text('Explore one phenomenon at a time. Keep what happened, what you felt, and what you think it means in view.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 22),
          _QuickCapture(store: store),
          const SizedBox(height: 24),
          Row(children: [const Expanded(child: Text('Your phenomena', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))), FilledButton.icon(onPressed: () => _createWorkspace(context, store), icon: const Icon(Icons.add), label: const Text('New workspace'))]),
          const SizedBox(height: 10),
          if (store.data.workspaces.isEmpty) const _EmptyCard(title: 'Start with a question', text: 'Create a workspace around one thing you want to understand.'),
          ...store.data.workspaces.map((workspace) => Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onOpen(workspace.id),
                  child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE9EEE7), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.visibility_outlined, color: _moss)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(workspace.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)), const SizedBox(height: 4), Text(workspace.question, maxLines: 2, overflow: TextOverflow.ellipsis)])),
                    PopupMenuButton<String>(
                      tooltip: 'Workspace actions',
                      onSelected: (action) async {
                        if (action == 'edit') await _editWorkspace(context, store, workspace);
                        if (action == 'delete' && await _confirmDeleteWorkspace(context, workspace)) {
                          await store.deleteWorkspace(workspace.id);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit title and question')),
                        PopupMenuItem(value: 'delete', child: Text('Delete workspace')),
                      ],
                    ),
                  ])),
                ),
              )),
          const SizedBox(height: 14),
          const _Notice(text: 'The starter workspace, symbols, and sample writing are labeled DEMO. They are examples, not personal records or research sources.'),
        ]),
      );
}

class _QuickCapture extends StatefulWidget {
  const _QuickCapture({required this.store});
  final NotebookStore store;
  @override
  State<_QuickCapture> createState() => _QuickCaptureState();
}

class _QuickCaptureState extends State<_QuickCapture> {
  final _controller = TextEditingController();
  String? _selectedId;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final workspaces = widget.store.data.workspaces;
    if (!workspaces.any((workspace) => workspace.id == _selectedId)) {
      _selectedId = workspaces.isEmpty ? null : workspaces.first.id;
    }
    return Card(color: const Color(0xFFEAEDE5), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick capture', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(controller: _controller, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'A fragment, question, or image to return to…')),
      const SizedBox(height: 10),
      Row(children: [
        if (workspaces.isNotEmpty) Expanded(child: DropdownButtonFormField<String>(value: _selectedId, decoration: const InputDecoration(labelText: 'Save to'), items: workspaces.map((w) => DropdownMenuItem(value: w.id, child: Text(w.title, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) => setState(() => _selectedId = value))) else const Expanded(child: Text('Create a workspace to save a note.')),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(onPressed: workspaces.isEmpty ? null : _save, icon: const Icon(Icons.bookmark_add_outlined), label: const Text('Save note')),
      ]),
    ])));
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _selectedId == null) return;
    await widget.store.addQuickNote(_selectedId!, text);
    if (!mounted) return;
    _controller.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved to the workspace.')));
  }
}

Future<void> _createWorkspace(BuildContext context, NotebookStore store) async {
  final title = TextEditingController();
  final question = TextEditingController();
  final created = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('New phenomenon'),
        content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'Short title')), const SizedBox(height: 12), TextField(controller: question, maxLines: 2, decoration: const InputDecoration(labelText: 'Question to explore'))])),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))],
      ));
  if (created == true && title.text.trim().isNotEmpty) await store.addWorkspace(title.text.trim(), question.text.trim());
  title.dispose(); question.dispose();
}

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key, required this.store, required this.workspace});
  final NotebookStore store;
  final PhenomenonWorkspace workspace;

  @override
  Widget build(BuildContext context) => DefaultTabController(length: 5, child: Column(children: [
        Material(color: _paper, child: TabBar(isScrollable: true, tabs: const [Tab(text: 'Overview'), Tab(text: 'Diary'), Tab(text: 'Reflection'), Tab(text: 'Fairy tale'), Tab(text: 'Sources')])),
        Expanded(child: TabBarView(children: [
          _WorkspaceOverview(store: store, workspace: workspace),
          _DiaryTab(store: store, workspace: workspace),
          _DocumentTab(store: store, workspace: workspace, fairyTale: false),
          _DocumentTab(store: store, workspace: workspace, fairyTale: true),
          _WorkspaceSources(store: store, workspace: workspace),
        ])),
      ]));
}

class _WorkspaceOverview extends StatelessWidget {
  const _WorkspaceOverview({required this.store, required this.workspace});
  final NotebookStore store;
  final PhenomenonWorkspace workspace;
  @override
  Widget build(BuildContext context) => PageFrame(child: ListView(padding: const EdgeInsets.all(24), children: [
        Text(workspace.question, style: const TextStyle(fontSize: 25, height: 1.25, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 16),
        const _Notice(text: 'Keep what you noticed separate from what you infer. A feeling can be real while an explanation remains uncertain.'),
        const SizedBox(height: 20),
          _SectionCard(title: 'Quick notes', child: workspace.quickNotes.isEmpty ? const Text('No fragments captured yet.') : Column(children: List.generate(workspace.quickNotes.length, (index) => ListTile(leading: const Icon(Icons.notes), title: Text(workspace.quickNotes[index]), contentPadding: EdgeInsets.zero, trailing: IconButton(tooltip: 'Remove note', icon: const Icon(Icons.close), onPressed: () async {
            final note = workspace.quickNotes[index];
            await store.deleteQuickNote(workspace.id, index);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Quick note removed.'), action: SnackBarAction(label: 'Undo', onPressed: () { unawaited(store.restoreQuickNote(workspace.id, index, note)); })));
          }))))),
        _SectionCard(title: 'Paired writing', child: Row(children: [Expanded(child: _MiniDocCard(label: 'Reflection', count: workspace.reflection.paragraphs.length)), const SizedBox(width: 12), Expanded(child: _MiniDocCard(label: 'Gnomy fairy tale', count: workspace.fairyTale.paragraphs.length))])),
        _SectionCard(title: 'Linked phenomena', child: _LinkedWorkspaces(store: store, workspace: workspace)),
      ]));
}

class _MiniDocCard extends StatelessWidget {
  const _MiniDocCard({required this.label, required this.count});
  final String label; final int count;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF4F1E9), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.edit_note, color: _moss), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w700)), Text('$count paragraphs')]));
}

class _DiaryTab extends StatelessWidget {
  const _DiaryTab({required this.store, required this.workspace});
  final NotebookStore store; final PhenomenonWorkspace workspace;
  @override
  Widget build(BuildContext context) => PageFrame(child: ListView(padding: const EdgeInsets.all(24), children: [
        Row(children: [const Expanded(child: Text('Reflection diary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))), FilledButton.icon(onPressed: () => _addDiary(context), icon: const Icon(Icons.add), label: const Text('New entry'))]),
        const SizedBox(height: 8), const Text('These prompts support reflection. They do not diagnose or determine what happened.'),
        const SizedBox(height: 14),
        if (workspace.diaryEntries.isEmpty) const _EmptyCard(title: 'No diary entries yet', text: 'Add a moment you want to understand.'),
        ...workspace.diaryEntries.map((entry) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Entry · ${entry.createdAt.toLocal().toString().split('.').first}', style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(tooltip: 'Edit entry', onPressed: () => _editDiary(context, entry), icon: const Icon(Icons.edit_outlined)),
                IconButton(tooltip: 'Delete entry', onPressed: () => _deleteDiary(context, entry), icon: const Icon(Icons.delete_outline)),
              ]),
              _ReadField(label: 'Observation', value: entry.observation), _ReadField(label: 'Feelings', value: entry.feelings), _ReadField(label: 'Interpretation', value: entry.interpretation), _ReadField(label: 'Uncertainty', value: entry.uncertainty), _ReadField(label: 'Possible explanations', value: entry.possibleExplanations),
              const SizedBox(height: 12),
              _DiarySymbolPicker(store: store, entry: entry),
            ])))),
      ]));

  Future<void> _addDiary(BuildContext context) async => _editDiary(context, null);

  Future<void> _editDiary(BuildContext context, DiaryEntry? entry) async {
    final fields = [
      TextEditingController(text: entry?.observation ?? ''),
      TextEditingController(text: entry?.feelings ?? ''),
      TextEditingController(text: entry?.interpretation ?? ''),
      TextEditingController(text: entry?.uncertainty ?? ''),
      TextEditingController(text: entry?.possibleExplanations ?? ''),
    ];
    const labels = ['What happened? (observation)', 'What did you feel?', 'What did you think it meant?', 'What remains uncertain?', 'What are other possible explanations?'];
    final save = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
          title: Text(entry == null ? 'New diary entry' : 'Edit diary entry'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  fields.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: fields[i],
                      maxLines: 2,
                      decoration: InputDecoration(labelText: labels[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save entry'))],
        ));
    if (save == true) {
      final updated = DiaryEntry(
        id: entry?.id ?? newId(),
        createdAt: entry?.createdAt ?? DateTime.now(),
        observation: fields[0].text,
        feelings: fields[1].text,
        interpretation: fields[2].text,
        uncertainty: fields[3].text,
        possibleExplanations: fields[4].text,
        symbolIds: entry?.symbolIds.toList(),
      );
      await store.saveDiaryEntry(workspace.id, updated);
    }
    for (final field in fields) { field.dispose(); }
  }

  Future<void> _deleteDiary(BuildContext context, DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete diary entry?'),
      content: const Text('This entry will be permanently removed.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (confirmed == true) await store.deleteDiaryEntry(workspace.id, entry.id);
  }
}

class _DiarySymbolPicker extends StatelessWidget {
  const _DiarySymbolPicker({required this.store, required this.entry});
  final NotebookStore store;
  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final selected = store.data.symbols.where((symbol) => entry.symbolIds.contains(symbol.id));
    return Wrap(spacing: 6, runSpacing: 4, children: [
      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Symbols:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
      ...selected.map((symbol) => InputChip(
            label: Text(symbol.name),
            avatar: Icon(Icons.auto_awesome, size: 16, color: Color(symbol.colorValue)),
            onDeleted: () { entry.symbolIds.remove(symbol.id); store.saveSoon(); },
          )),
      PopupMenuButton<String>(
        tooltip: 'Attach a symbol to this reflection entry',
        icon: const Icon(Icons.add_circle_outline),
        itemBuilder: (context) => store.data.symbols.isEmpty
            ? const [PopupMenuItem<String>(enabled: false, child: Text('Create a symbol first'))]
            : store.data.symbols.map((symbol) => PopupMenuItem(value: symbol.id, child: Text((entry.symbolIds.contains(symbol.id) ? '✓ ' : '') + symbol.name))).toList(),
        onSelected: (id) {
          if (entry.symbolIds.contains(id)) {
            entry.symbolIds.remove(id);
          } else {
            entry.symbolIds.add(id);
          }
          store.saveSoon();
        },
      ),
    ]);
  }
}

class _ReadField extends StatelessWidget {
  const _ReadField({required this.label, required this.value});
  final String label; final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _moss)), const SizedBox(height: 3), Text(value.isEmpty ? '—' : value)]));
}

class _DocumentTab extends StatelessWidget {
  const _DocumentTab({required this.store, required this.workspace, required this.fairyTale});
  final NotebookStore store; final PhenomenonWorkspace workspace; final bool fairyTale;
  @override
  Widget build(BuildContext context) {
    final document = fairyTale ? workspace.fairyTale : workspace.reflection;
    final title = fairyTale ? 'Gnomy fairy tale' : 'Reflection';
    return PageFrame(child: ListView(padding: const EdgeInsets.all(24), children: [
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(fairyTale ? 'A creative adaptation linked to the reflection. It can transform events and images.' : 'Explore the idea in your own words. Keep interpretations open to revision.'),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(fairyTale ? 2 : 3),
          icon: const Icon(Icons.compare_arrows),
          label: Text(fairyTale ? 'Open paired reflection' : 'Open paired fairy tale'),
        ),
      ),
      const SizedBox(height: 16),
      if (document.paragraphs.isEmpty) const _EmptyCard(title: 'A blank page', text: 'Add a paragraph when you are ready.'),
      ...document.paragraphs.map((paragraph) => _ParagraphCard(
            store: store,
            paragraph: paragraph,
            onDelete: () async {
              final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
                title: const Text('Delete paragraph?'),
                content: const Text('This paragraph and its annotations will be removed.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
              ));
              if (confirmed != true) return;
              document.paragraphs.removeWhere((item) => item.id == paragraph.id);
              store.saveSoon();
            },
          )),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () { document.paragraphs.add(DocumentParagraph(id: newId(), text: '')); store.saveSoon(); }, icon: const Icon(Icons.add), label: const Text('Add paragraph'))),
    ]));
  }
}

class _ParagraphCard extends StatelessWidget {
  const _ParagraphCard({required this.store, required this.paragraph, required this.onDelete});
  final NotebookStore store; final DocumentParagraph paragraph;
  final Future<void> Function() onDelete;
  @override
  Widget build(BuildContext context) {
    final symbols = store.data.symbols.where((s) => paragraph.symbolIds.contains(s.id)).toList();
    final sources = store.data.sources.where((s) => paragraph.sourceIds.contains(s.id)).toList();
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: TextFormField(key: ValueKey(paragraph.id), initialValue: paragraph.text, minLines: 2, maxLines: 8, onChanged: (value) { paragraph.text = value; store.saveSoon(); }, decoration: const InputDecoration(hintText: 'Write a paragraph…', filled: false))),
        IconButton(tooltip: 'Delete paragraph', onPressed: () { unawaited(onDelete()); }, icon: const Icon(Icons.delete_outline)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 4, children: [
        ...symbols.map((symbol) => InputChip(label: Text(symbol.name), avatar: Icon(Icons.auto_awesome, size: 16, color: Color(symbol.colorValue)), onDeleted: () { paragraph.symbolIds.remove(symbol.id); store.saveSoon(); })),
        ...sources.map((source) => InputChip(label: Text(source.citation, overflow: TextOverflow.ellipsis), avatar: const Icon(Icons.bookmark_outline, size: 16), onDeleted: () { paragraph.sourceIds.remove(source.id); store.saveSoon(); })),
        PopupMenuButton<String>(tooltip: 'Annotate paragraph', icon: const Icon(Icons.add_circle_outline), itemBuilder: (context) => [
          if (store.data.symbols.isEmpty && store.data.sources.isEmpty) const PopupMenuItem(enabled: false, child: Text('Add a symbol or source first')),
          if (store.data.symbols.isNotEmpty) const PopupMenuItem(enabled: false, child: Text('Add symbol')),
          ...store.data.symbols.map((symbol) => PopupMenuItem(value: 's:${symbol.id}', child: Text((paragraph.symbolIds.contains(symbol.id) ? '✓ ' : '') + symbol.name))),
          if (store.data.sources.isNotEmpty) const PopupMenuItem(enabled: false, child: Text('Link source')),
          ...store.data.sources.map((source) => PopupMenuItem(value: 'r:${source.id}', child: Text((paragraph.sourceIds.contains(source.id) ? '✓ ' : '') + source.citation, overflow: TextOverflow.ellipsis))),
        ], onSelected: (value) {
          if (value.startsWith('s:')) {
            final id = value.substring(2);
            paragraph.symbolIds.contains(id) ? paragraph.symbolIds.remove(id) : paragraph.symbolIds.add(id);
          } else {
            final id = value.substring(2);
            paragraph.sourceIds.contains(id) ? paragraph.sourceIds.remove(id) : paragraph.sourceIds.add(id);
          }
          store.saveSoon();
        }),
      ]),
    ])));
  }
}

class SymbolsPage extends StatelessWidget {
  const SymbolsPage({super.key, required this.store}); final NotebookStore store;
  @override
  Widget build(BuildContext context) => PageFrame(child: ListView(padding: const EdgeInsets.all(24), children: [
        Row(children: [const Expanded(child: Text('Your symbols', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700))), FilledButton.icon(onPressed: () => _addSymbol(context), icon: const Icon(Icons.add), label: const Text('Add symbol'))]),
        const SizedBox(height: 8), const Text('Give each image a meaning that makes sense to you. Meanings can change.'), const SizedBox(height: 14),
        ...store.data.symbols.map((symbol) => Card(child: ListTile(
              leading: CircleAvatar(backgroundColor: Color(symbol.colorValue).withAlpha(46), child: Icon(Icons.auto_awesome, color: Color(symbol.colorValue))),
              title: Text(symbol.name),
              subtitle: Text(symbol.meaning),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'edit') await _editSymbol(context, symbol);
                  if (action == 'delete') {
                    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
                      title: const Text('Remove symbol?'),
                      content: Text('“${symbol.name}” will be removed from your symbol list and all annotations.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))],
                    ));
                    if (confirmed == true) await store.deleteSymbol(symbol.id);
                  }
                },
                itemBuilder: (context) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Remove'))],
              ),
            ))),
        if (store.data.symbols.isEmpty) const _EmptyCard(title: 'No symbols yet', text: 'Create a symbol and define what it means in your writing.'),
      ]));
  Future<void> _addSymbol(BuildContext context) async {
    final name = TextEditingController(); final meaning = TextEditingController();
    var selectedColor = _symbolPalette.values.first;
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('New symbol'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(controller: meaning, maxLines: 2, decoration: const InputDecoration(labelText: 'Meaning')),
        const SizedBox(height: 12),
        Wrap(spacing: 6, children: _symbolPalette.entries.map((entry) => ChoiceChip(label: Text(entry.key), avatar: CircleAvatar(backgroundColor: Color(entry.value), radius: 8), selected: selectedColor == entry.value, onSelected: (_) => setDialogState(() => selectedColor = entry.value))).toList()),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    )));
    if (saved == true && name.text.trim().isNotEmpty) await store.addSymbol(name.text.trim(), meaning.text.trim(), colorValue: selectedColor);
    name.dispose(); meaning.dispose();
  }

  Future<void> _editSymbol(BuildContext context, NotebookSymbol symbol) async {
    final name = TextEditingController(text: symbol.name);
    final meaning = TextEditingController(text: symbol.meaning);
    var selectedColor = symbol.colorValue;
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Edit symbol'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(controller: meaning, maxLines: 2, decoration: const InputDecoration(labelText: 'Meaning')),
        const SizedBox(height: 12),
        Wrap(spacing: 6, children: _symbolPalette.entries.map((entry) => ChoiceChip(label: Text(entry.key), avatar: CircleAvatar(backgroundColor: Color(entry.value), radius: 8), selected: selectedColor == entry.value, onSelected: (_) => setDialogState(() => selectedColor = entry.value))).toList()),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    )));
    if (saved == true && name.text.trim().isNotEmpty) {
      symbol.name = name.text;
      symbol.meaning = meaning.text;
      symbol.colorValue = selectedColor;
      await store.updateSymbol(symbol);
    }
    name.dispose();
    meaning.dispose();
  }
}

class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key, required this.store}); final NotebookStore store;
  @override
  Widget build(BuildContext context) => PageFrame(child: ListView(padding: const EdgeInsets.all(24), children: [
        Row(children: [const Expanded(child: Text('Source shelf', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700))), FilledButton.icon(onPressed: () => _addSource(context), icon: const Icon(Icons.add), label: const Text('Add source'))]),
        const SizedBox(height: 8), const Text('Add references manually. A source can be linked to a paragraph; the app does not rate or verify it.'), const SizedBox(height: 14),
        ...store.data.sources.map((source) => Card(child: ListTile(
              leading: const Icon(Icons.menu_book_outlined, color: _moss),
              title: Text(source.citation),
              subtitle: Text([source.url, source.notes].where((s) => s.isNotEmpty).join('\n')),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'edit') await _editSource(context, source);
                  if (action == 'delete') {
                    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
                      title: const Text('Remove source?'),
                      content: Text('“${source.citation}” will be removed from this notebook and its passage links.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))],
                    ));
                    if (confirmed == true) await store.deleteSource(source.id);
                  }
                },
                itemBuilder: (context) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Remove'))],
              ),
            ))),
        if (store.data.sources.isEmpty) const _EmptyCard(title: 'No sources yet', text: 'Add a reference when you want to connect research with a specific passage.'),
      ]));
  Future<void> _addSource(BuildContext context) async {
    final citation = TextEditingController(); final url = TextEditingController(); final notes = TextEditingController();
    final saved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Add source'), content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: citation, decoration: const InputDecoration(labelText: 'Reference / citation')), const SizedBox(height: 10), TextField(controller: url, decoration: const InputDecoration(labelText: 'URL (optional)')), const SizedBox(height: 10), TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Your note (optional)'))])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save source'))]));
    if (saved == true && citation.text.trim().isNotEmpty) await store.addSource(citation.text.trim(), url.text.trim(), notes.text.trim());
    citation.dispose(); url.dispose(); notes.dispose();
  }

  Future<void> _editSource(BuildContext context, SourceReference source) async {
    final citation = TextEditingController(text: source.citation);
    final url = TextEditingController(text: source.url);
    final notes = TextEditingController(text: source.notes);
    final saved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Edit source'),
      content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: citation, decoration: const InputDecoration(labelText: 'Reference / citation')), const SizedBox(height: 10), TextField(controller: url, decoration: const InputDecoration(labelText: 'URL (optional)')), const SizedBox(height: 10), TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Your note (optional)'))])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    ));
    if (saved == true && citation.text.trim().isNotEmpty) {
      source.citation = citation.text;
      source.url = url.text;
      source.notes = notes.text;
      await store.updateSource(source);
    }
    citation.dispose();
    url.dispose();
    notes.dispose();
  }
}

class _WorkspaceSources extends StatelessWidget {
  const _WorkspaceSources({required this.store, required this.workspace}); final NotebookStore store; final PhenomenonWorkspace workspace;
  @override
  Widget build(BuildContext context) => PageFrame(child: ListView(padding: const EdgeInsets.all(24), children: [const Text('Sources used in this workspace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), const SizedBox(height: 12), const Text('Sources attached to paragraphs appear here as you annotate the reflection or fairy tale.'), const SizedBox(height: 14), ..._usedSources().map((source) => Card(child: ListTile(leading: const Icon(Icons.bookmark_outline), title: Text(source.citation), subtitle: Text(source.notes))))]));
  List<SourceReference> _usedSources() {
    final ids = <String>{};
    for (final paragraph in [...workspace.reflection.paragraphs, ...workspace.fairyTale.paragraphs]) { ids.addAll(paragraph.sourceIds); }
    return store.data.sources.where((source) => ids.contains(source.id)).toList();
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key, required this.store, required this.onOpen}); final NotebookStore store; final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => PageFrame(child: ListView(padding: const EdgeInsets.all(24), children: [
        Row(children: [const Expanded(child: Text('Phenomenon map', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700))), FilledButton.icon(onPressed: store.data.workspaces.length < 2 ? () => _createWorkspace(context, store) : () => _link(context), icon: Icon(store.data.workspaces.length < 2 ? Icons.add : Icons.add_link), label: Text(store.data.workspaces.isEmpty ? 'Create workspace' : store.data.workspaces.length == 1 ? 'Create another' : 'Link two'))]),
        const SizedBox(height: 8), const Text('A simple map of questions you want to explore. A link is a reminder to compare, not a claim that two phenomena are the same.'), const SizedBox(height: 14),
        if (store.data.workspaces.isEmpty) const _EmptyCard(title: 'No phenomena to map yet', text: 'Create a workspace first, then link it to another question.'),
        ...store.data.workspaces.map((workspace) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [TextButton.icon(onPressed: () => onOpen(workspace.id), icon: const Icon(Icons.visibility_outlined), label: Text(workspace.title)), Text(workspace.question), const Divider(), Wrap(spacing: 8, children: workspace.relatedWorkspaceIds.map((id) { final related = store.data.workspaces.where((item) => item.id == id); return related.isEmpty ? const SizedBox.shrink() : InputChip(label: Text(related.first.title), onPressed: () => onOpen(id)); }).toList())])))),
      ]));
  Future<void> _link(BuildContext context) async {
    if (store.data.workspaces.length < 2) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create at least two workspaces first.'))); return; }
    String first = store.data.workspaces[0].id; String second = store.data.workspaces[1].id;
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(title: const Text('Link phenomena'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: first, items: store.data.workspaces.map((w) => DropdownMenuItem(value: w.id, child: Text(w.title))).toList(), onChanged: (v) => setLocal(() => first = v ?? first)), const SizedBox(height: 10), DropdownButtonFormField<String>(value: second, items: store.data.workspaces.map((w) => DropdownMenuItem(value: w.id, child: Text(w.title))).toList(), onChanged: (v) => setLocal(() => second = v ?? second)), if (first == second) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Choose two different workspaces.'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: first == second ? null : () async { await store.linkWorkspaces(first, second); if (context.mounted) Navigator.pop(context); }, child: const Text('Link'))])));
  }
}

class _LinkedWorkspaces extends StatelessWidget {
  const _LinkedWorkspaces({required this.store, required this.workspace}); final NotebookStore store; final PhenomenonWorkspace workspace;
  @override
  Widget build(BuildContext context) {
    final linked = store.data.workspaces.where((item) => workspace.relatedWorkspaceIds.contains(item.id)).toList();
    return linked.isEmpty
        ? const Text('No links yet. Use the map to connect related questions.')
        : Wrap(
            spacing: 8,
            children: linked.map((item) => InputChip(
              avatar: const Icon(Icons.hub_outlined, size: 16),
              label: Text(item.title),
              onDeleted: () { unawaited(store.unlinkWorkspaces(workspace.id, item.id)); },
            )).toList(),
          );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store}); final NotebookStore store;
  @override
  Widget build(BuildContext context) => PageFrame(child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Settings & data', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)), const SizedBox(height: 14),
        const _Notice(text: 'This prototype stores data in browser local storage. It is not encrypted or synced. Clearing browser data can remove your notebook. Do not treat it as a secure archive.'),
        Card(child: ListTile(leading: const Icon(Icons.save_outlined), title: const Text('Save now'), subtitle: const Text('Wait for the local write to finish before closing the app.'), trailing: const Icon(Icons.chevron_right), onTap: () async { await store.flush(); if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.saveFailed ? 'Could not save to browser storage.' : 'Notebook saved locally.'))); })),
        const SizedBox(height: 16), Card(child: ListTile(leading: const Icon(Icons.data_object), title: const Text('View JSON export'), subtitle: const Text('Copy the current notebook data for a manual backup.'), trailing: const Icon(Icons.chevron_right), onTap: () => _showExport(context))),
        Card(child: ListTile(leading: const Icon(Icons.file_open_outlined), title: const Text('Import JSON backup'), subtitle: const Text('Paste a backup. Import replaces the current notebook.'), trailing: const Icon(Icons.chevron_right), onTap: () => _showImport(context))),
        const Card(child: ListTile(leading: Icon(Icons.cloud_off_outlined), title: Text('No account or cloud sync'), subtitle: Text('This version makes no network requests and uses no API keys.'))),
      ]));
  void _showExport(BuildContext context) { final text = const JsonEncoder.withIndent('  ').convert(store.data.toJson()); showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('JSON export'), content: SizedBox(width: 680, child: SingleChildScrollView(child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))])); }

  Future<void> _showImport(BuildContext context) async {
    final controller = TextEditingController();
    String? errorText;
    final imported = await showDialog<NotebookData>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Import JSON backup'),
        content: SizedBox(
          width: 680,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Paste a JSON export. It will replace all current workspaces, symbols, and sources after confirmation.'),
            const SizedBox(height: 12),
            TextField(controller: controller, minLines: 8, maxLines: 14, decoration: const InputDecoration(hintText: 'Paste JSON here…', alignLabelWithHint: true)),
            if (errorText != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorText!, style: const TextStyle(color: Colors.red))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            try {
              final decoded = jsonDecode(controller.text);
              if (decoded is! Map) throw const FormatException('The backup must contain a JSON object.');
              final data = NotebookData.fromJson(Map<String, dynamic>.from(decoded));
              Navigator.pop(dialogContext, data);
            } catch (error) {
              setDialogState(() => errorText = 'Could not read this backup: $error');
            }
          }, child: const Text('Continue')),
        ],
      )),
    );
    controller.dispose();
    if (imported == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Replace this notebook?'),
      content: const Text('The imported backup will replace all data currently stored in this browser.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Replace notebook'))],
    ));
    if (confirmed == true) await store.replaceData(imported);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child}); final String title; final Widget child;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 14), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 12), child])));
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.text}); final String title; final String text;
  @override
  Widget build(BuildContext context) => Card(color: const Color(0xFFF1EFE8), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(text)])));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text}); final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFE9EEE7), borderRadius: BorderRadius.circular(14)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline, color: _moss), const SizedBox(width: 10), Expanded(child: Text(text))]));
}
