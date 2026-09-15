import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/startup_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());

  // Heavy initialisation runs after the first frame so the launch screen
  // disappears quickly; the splash screen awaits it.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(StartupService.start());
  });
}
