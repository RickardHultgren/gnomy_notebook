import 'package:flutter/material.dart';

import 'app.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = NotebookStore();
  await store.load();
  runApp(GnomyNotebookApp(store: store));
}
