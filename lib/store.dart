import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class NotebookStore extends ChangeNotifier {
  static const _storageKey = 'gnomy_notebook_data_v1';
  NotebookData _data = NotebookData(workspaces: [], symbols: [], sources: []);
  bool _loaded = false;
  bool _saveFailed = false;
  bool _savePending = false;
  String? _loadError;
  String? _unreadableData;
  Timer? _saveTimer;
  Future<void> _writeQueue = Future<void>.value();

  NotebookData get data => _data;
  bool get loaded => _loaded;
  bool get saveFailed => _saveFailed;
  bool get savePending => _savePending;
  String? get loadError => _loadError;
  String? get unreadableData => _unreadableData;

  Future<void> load() async {
    _loaded = false;
    _loadError = null;
    _unreadableData = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      _saveFailed = false;
      if (stored == null) {
        _data = demoData();
        await _persist();
      } else {
        try {
          _data = NotebookData.fromJson(Map<String, dynamic>.from(jsonDecode(stored) as Map));
        } catch (error) {
          _data = NotebookData(workspaces: [], symbols: [], sources: []);
          _unreadableData = stored;
          _loadError = 'Saved notebook data could not be read. The stored text has been kept unchanged.';
        }
      }
    } catch (error) {
      _data = NotebookData(workspaces: [], symbols: [], sources: []);
      _saveFailed = true;
      _loadError = 'Browser storage could not be opened: $error';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() {
    final payload = _data.encode();
    _savePending = true;
    notifyListeners();
    final write = _writeQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, payload);
        _saveFailed = false;
      } catch (_) {
        _saveFailed = true;
      }
    });
    _writeQueue = write;
    return write.whenComplete(() {
      if (identical(_writeQueue, write)) {
        _savePending = false;
        notifyListeners();
      }
    });
  }

  Future<void> retryLoad() => load();

  Future<void> replaceUnreadableDataWithDemo() async {
    _data = demoData();
    _loadError = null;
    _unreadableData = null;
    await _persist();
  }

  Future<void> replaceData(NotebookData imported) async {
    _data = imported;
    _loadError = null;
    _unreadableData = null;
    await _persist();
  }

  Future<void> addWorkspace(String title, String question) async {
    final reflectionId = newId();
    final storyId = newId();
    _data.workspaces.insert(
      0,
      PhenomenonWorkspace(
        id: newId(),
        title: title,
        question: question,
        createdAt: DateTime.now(),
        diaryEntries: [],
        quickNotes: [],
        reflection: WritingDocument(id: reflectionId, pairedDocumentId: storyId, paragraphs: []),
        fairyTale: WritingDocument(id: storyId, pairedDocumentId: reflectionId, paragraphs: []),
        relatedWorkspaceIds: [],
      ),
    );
    await _persist();
  }

  Future<void> updateWorkspace(PhenomenonWorkspace workspace) async {
    workspace.title = workspace.title.trim().isEmpty ? 'Untitled phenomenon' : workspace.title.trim();
    workspace.question = workspace.question.trim();
    await _persist();
  }

  Future<void> deleteWorkspace(String id) async {
    _data.workspaces.removeWhere((workspace) => workspace.id == id);
    for (final workspace in _data.workspaces) {
      workspace.relatedWorkspaceIds.remove(id);
    }
    await _persist();
  }

  Future<void> saveDiaryEntry(String workspaceId, DiaryEntry entry) async {
    final workspace = _workspace(workspaceId);
    if (workspace == null) return;
    final index = workspace.diaryEntries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      workspace.diaryEntries.insert(0, entry);
    } else {
      workspace.diaryEntries[index] = entry;
    }
    await _persist();
  }

  Future<void> deleteDiaryEntry(String workspaceId, String entryId) async {
    _workspace(workspaceId)?.diaryEntries.removeWhere((entry) => entry.id == entryId);
    await _persist();
  }

  Future<void> addQuickNote(String workspaceId, String text) async {
    final workspace = _workspace(workspaceId);
    if (workspace == null || text.trim().isEmpty) return;
    workspace.quickNotes.insert(0, text.trim());
    await _persist();
  }

  Future<void> deleteQuickNote(String workspaceId, int index) async {
    final workspace = _workspace(workspaceId);
    if (workspace == null || index < 0 || index >= workspace.quickNotes.length) return;
    workspace.quickNotes.removeAt(index);
    await _persist();
  }

  Future<void> restoreQuickNote(String workspaceId, int index, String text) async {
    final workspace = _workspace(workspaceId);
    if (workspace == null) return;
    final safeIndex = index < 0 ? 0 : (index > workspace.quickNotes.length ? workspace.quickNotes.length : index);
    workspace.quickNotes.insert(safeIndex, text);
    await _persist();
  }

  void saveSoon() {
    _saveTimer?.cancel();
    if (!_savePending) {
      _savePending = true;
      notifyListeners();
    }
    _saveTimer = Timer(const Duration(milliseconds: 450), () => unawaited(_persist()));
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    return _persist();
  }

  Future<void> addSymbol(String name, String meaning, {int colorValue = 0xFF647C67}) async {
    _data.symbols.add(NotebookSymbol(id: newId(), name: name, meaning: meaning, colorValue: colorValue));
    await _persist();
  }

  Future<void> updateSymbol(NotebookSymbol symbol) async {
    symbol.name = symbol.name.trim();
    symbol.meaning = symbol.meaning.trim();
    await _persist();
  }

  Future<void> deleteSymbol(String id) async {
    _data.symbols.removeWhere((symbol) => symbol.id == id);
    for (final workspace in _data.workspaces) {
      for (final entry in workspace.diaryEntries) {
        entry.symbolIds.remove(id);
      }
      for (final paragraph in [...workspace.reflection.paragraphs, ...workspace.fairyTale.paragraphs]) {
        paragraph.symbolIds.remove(id);
      }
    }
    await _persist();
  }

  Future<void> addSource(String citation, String url, String notes) async {
    _data.sources.add(SourceReference(id: newId(), citation: citation, url: url, notes: notes));
    await _persist();
  }

  Future<void> updateSource(SourceReference source) async {
    source.citation = source.citation.trim();
    source.url = source.url.trim();
    source.notes = source.notes.trim();
    await _persist();
  }

  Future<void> deleteSource(String id) async {
    _data.sources.removeWhere((source) => source.id == id);
    for (final workspace in _data.workspaces) {
      for (final paragraph in [...workspace.reflection.paragraphs, ...workspace.fairyTale.paragraphs]) {
        paragraph.sourceIds.remove(id);
      }
    }
    await _persist();
  }

  Future<void> linkWorkspaces(String firstId, String secondId) async {
    final first = _workspace(firstId);
    final second = _workspace(secondId);
    if (first == null || second == null || firstId == secondId) return;
    if (!first.relatedWorkspaceIds.contains(secondId)) first.relatedWorkspaceIds.add(secondId);
    if (!second.relatedWorkspaceIds.contains(firstId)) second.relatedWorkspaceIds.add(firstId);
    await _persist();
  }

  Future<void> unlinkWorkspaces(String firstId, String secondId) async {
    _workspace(firstId)?.relatedWorkspaceIds.remove(secondId);
    _workspace(secondId)?.relatedWorkspaceIds.remove(firstId);
    await _persist();
  }

  PhenomenonWorkspace? _workspace(String id) {
    for (final workspace in _data.workspaces) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }
}
