import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/workspace/application/workspace_controller.dart';
import '../features/workspace/presentation/login_screen.dart';
import '../features/workspace/presentation/workspace_screen.dart';
import 'theme.dart';

class EdmApp extends StatefulWidget {
  const EdmApp({super.key, required this.controller, required this.configured});

  final WorkspaceController controller;
  final bool configured;

  @override
  State<EdmApp> createState() => _EdmAppState();
}

class _EdmAppState extends State<EdmApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Аврора · Документы',
    debugShowCheckedModeBanner: false,
    theme: edmTheme(Brightness.light),
    darkTheme: edmTheme(Brightness.dark),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => widget.controller.session == null
        ? LoginScreen(controller: widget.controller, configured: widget.configured)
        : WorkspaceScreen(controller: widget.controller),
    ),
  );
}
