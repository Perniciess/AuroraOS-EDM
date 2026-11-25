import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../application/workspace_controller.dart';

class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key, required this.path, required this.title, required this.controller});

  final String path;
  final String title;
  final WorkspaceController controller;

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (widget.controller.session == null && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(child: Column(children: [
      if (widget.controller.offline)
        const Padding(padding: EdgeInsets.all(12), child: Text(
          'Сохранённая версия. Актуальность задания без сети не проверена.')),
      Expanded(child: PdfViewer.file(widget.path)),
    ])),
  );
}
