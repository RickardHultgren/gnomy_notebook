import 'dart:convert';

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

class NotebookData {
  NotebookData({required this.workspaces, required this.symbols, required this.sources});

  final List<PhenomenonWorkspace> workspaces;
  final List<NotebookSymbol> symbols;
  final List<SourceReference> sources;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'workspaces': workspaces.map((item) => item.toJson()).toList(),
        'symbols': symbols.map((item) => item.toJson()).toList(),
        'sources': sources.map((item) => item.toJson()).toList(),
      };

  factory NotebookData.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int? ?? 1;
    if (schemaVersion > 1) {
      throw FormatException('Notebook schema version $schemaVersion is newer than this app supports.');
    }
    return NotebookData(
      workspaces: (json['workspaces'] as List<dynamic>? ?? [])
          .map((item) => PhenomenonWorkspace.fromJson(item as Map<String, dynamic>))
          .toList(),
      symbols: (json['symbols'] as List<dynamic>? ?? [])
          .map((item) => NotebookSymbol.fromJson(item as Map<String, dynamic>))
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? [])
          .map((item) => SourceReference.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());
}

class PhenomenonWorkspace {
  PhenomenonWorkspace({
    required this.id,
    required this.title,
    required this.question,
    required this.createdAt,
    required this.diaryEntries,
    required this.quickNotes,
    required this.reflection,
    required this.fairyTale,
    required this.relatedWorkspaceIds,
  });

  final String id;
  String title;
  String question;
  final DateTime createdAt;
  List<DiaryEntry> diaryEntries;
  List<String> quickNotes;
  WritingDocument reflection;
  WritingDocument fairyTale;
  List<String> relatedWorkspaceIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'question': question,
        'createdAt': createdAt.toIso8601String(),
        'diaryEntries': diaryEntries.map((item) => item.toJson()).toList(),
        'quickNotes': quickNotes,
        'reflection': reflection.toJson(),
        'fairyTale': fairyTale.toJson(),
        'relatedWorkspaceIds': relatedWorkspaceIds,
      };

  factory PhenomenonWorkspace.fromJson(Map<String, dynamic> json) {
    final reflection = WritingDocument.fromJson(json['reflection'] as Map<String, dynamic>);
    var fairyTale = WritingDocument.fromJson(json['fairyTale'] as Map<String, dynamic>);
    if (fairyTale.id == reflection.id) {
      fairyTale = WritingDocument(id: newId(), pairedDocumentId: reflection.id, paragraphs: fairyTale.paragraphs);
    }
    reflection.pairedDocumentId = fairyTale.id;
    fairyTale.pairedDocumentId = reflection.id;
    return PhenomenonWorkspace(
      id: json['id'] as String? ?? newId(),
      title: json['title'] as String? ?? 'Untitled phenomenon',
      question: json['question'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      diaryEntries: (json['diaryEntries'] as List<dynamic>? ?? [])
          .map((item) => DiaryEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      quickNotes: (json['quickNotes'] as List<dynamic>? ?? []).cast<String>(),
      reflection: reflection,
      fairyTale: fairyTale,
      relatedWorkspaceIds: (json['relatedWorkspaceIds'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}

class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.createdAt,
    this.observation = '',
    this.feelings = '',
    this.interpretation = '',
    this.uncertainty = '',
    this.possibleExplanations = '',
    List<String>? symbolIds,
  }) : symbolIds = symbolIds ?? [];

  final String id;
  final DateTime createdAt;
  String observation;
  String feelings;
  String interpretation;
  String uncertainty;
  String possibleExplanations;
  List<String> symbolIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'observation': observation,
        'feelings': feelings,
        'interpretation': interpretation,
        'uncertainty': uncertainty,
        'possibleExplanations': possibleExplanations,
        'symbolIds': symbolIds,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
        id: json['id'] as String? ?? newId(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        observation: json['observation'] as String? ?? '',
        feelings: json['feelings'] as String? ?? '',
        interpretation: json['interpretation'] as String? ?? '',
        uncertainty: json['uncertainty'] as String? ?? '',
        possibleExplanations: json['possibleExplanations'] as String? ?? '',
        symbolIds: (json['symbolIds'] as List<dynamic>? ?? []).cast<String>(),
      );
}

class WritingDocument {
  WritingDocument({required this.id, required this.pairedDocumentId, required this.paragraphs});

  final String id;
  String pairedDocumentId;
  List<DocumentParagraph> paragraphs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'pairedDocumentId': pairedDocumentId,
        'paragraphs': paragraphs.map((item) => item.toJson()).toList(),
      };

  factory WritingDocument.fromJson(Map<String, dynamic> json) => WritingDocument(
        id: json['id'] as String? ?? newId(),
        pairedDocumentId: json['pairedDocumentId'] as String? ?? '',
        paragraphs: (json['paragraphs'] as List<dynamic>? ?? [])
            .map((item) => DocumentParagraph.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class DocumentParagraph {
  DocumentParagraph({required this.id, required this.text, List<String>? symbolIds, List<String>? sourceIds})
      : symbolIds = symbolIds ?? [],
        sourceIds = sourceIds ?? [];

  final String id;
  String text;
  List<String> symbolIds;
  List<String> sourceIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'symbolIds': symbolIds,
        'sourceIds': sourceIds,
      };

  factory DocumentParagraph.fromJson(Map<String, dynamic> json) => DocumentParagraph(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        symbolIds: (json['symbolIds'] as List<dynamic>? ?? []).cast<String>(),
        sourceIds: (json['sourceIds'] as List<dynamic>? ?? []).cast<String>(),
      );
}

class NotebookSymbol {
  NotebookSymbol({required this.id, required this.name, required this.meaning, this.colorValue = 0xFF647C67});

  final String id;
  String name;
  String meaning;
  int colorValue;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'meaning': meaning, 'colorValue': colorValue};

  factory NotebookSymbol.fromJson(Map<String, dynamic> json) => NotebookSymbol(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Symbol',
        meaning: json['meaning'] as String? ?? '',
        colorValue: json['colorValue'] as int? ?? 0xFF647C67,
      );
}

class SourceReference {
  SourceReference({required this.id, required this.citation, this.url = '', this.notes = ''});

  final String id;
  String citation;
  String url;
  String notes;

  Map<String, dynamic> toJson() => {'id': id, 'citation': citation, 'url': url, 'notes': notes};

  factory SourceReference.fromJson(Map<String, dynamic> json) => SourceReference(
        id: json['id'] as String,
        citation: json['citation'] as String? ?? '',
        url: json['url'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

NotebookData demoData() {
  final reflectionId = newId();
  final storyId = newId();
  final workspaceId = newId();
  final lens = NotebookSymbol(id: newId(), name: 'DEMO · Lens', meaning: 'A shift in perspective.', colorValue: 0xFF607A8A);
  final lantern = NotebookSymbol(id: newId(), name: 'DEMO · Storm lantern light', meaning: 'A feeling of cautious warmth.', colorValue: 0xFFCC9558);
  final workspace = PhenomenonWorkspace(
    id: workspaceId,
    title: 'DEMO · Feeling blamed',
    question: 'Why can a question feel like blame?',
    createdAt: DateTime.now(),
    diaryEntries: [
      DiaryEntry(
        id: newId(),
        createdAt: DateTime.now(),
        observation: 'Demo: someone asks why a task is unfinished.',
        feelings: 'Demo: tension and an urge to explain.',
        interpretation: 'Demo: “They think I am careless.”',
        uncertainty: 'Demo: I do not know what the other person intended.',
        possibleExplanations: 'Demo: the question may be neutral, impatient, or shaped by earlier exchanges.',
      ),
    ],
    quickNotes: ['DEMO NOTE: What did I hear, and what did I infer?'],
    reflection: WritingDocument(
      id: reflectionId,
      pairedDocumentId: storyId,
      paragraphs: [
        DocumentParagraph(id: newId(), text: 'DEMO REFLECTION: A question can arrive as a request for information and still be heard as a verdict.'),
        DocumentParagraph(id: newId(), text: 'DEMO REFLECTION: The feeling is real; the interpretation of the other person’s intention remains uncertain.'),
      ],
    ),
    fairyTale: WritingDocument(
      id: storyId,
      pairedDocumentId: reflectionId,
      paragraphs: [
        DocumentParagraph(id: newId(), text: 'DEMO FABLE: Gnomy heard a knock in the forest and mistook its echo for a sentence.'),
        DocumentParagraph(id: newId(), text: 'DEMO FABLE: He turned the lens, waited, and listened for what the knock had actually asked.'),
      ],
    ),
    relatedWorkspaceIds: [],
  );
  return NotebookData(workspaces: [workspace], symbols: [lens, lantern], sources: []);
}
