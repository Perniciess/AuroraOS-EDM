import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../application/workspace_controller.dart';
import '../domain/workspace_repository.dart';
import 'common.dart';
import 'pdf_screen.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key, required this.controller});

  final WorkspaceController controller;

  Future<void> _open(BuildContext context, Assignment assignment) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _Details(controller: controller, assignment: assignment),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Документы'),
        actions: [
          IconButton(tooltip: 'Обновить задания',
            onPressed: controller.busy ? null : () => controller.refresh(),
            icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Выйти из учётной записи',
            onPressed: controller.busy ? null : () => controller.logout(),
            icon: const Icon(Icons.logout)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Text('РАБОЧЕЕ ПРОСТРАНСТВО', style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1.2, color: theme.colorScheme.primary)),
              const SizedBox(height: 12),
              Text('Ваши задания', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Назначены пользователю ${controller.session?.username ?? ''}',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              if (controller.offline) ...[
                const MessageCard(message: 'Нет связи с сервером. Показаны сохранённые задания; их актуальность не проверена.'),
                const SizedBox(height: 16),
              ],
              if (controller.busy) ...[
                const LinearProgressIndicator(semanticsLabel: 'Загрузка заданий'),
                const SizedBox(height: 24),
              ],
              if (controller.error != null) ...[
                MessageCard(message: controller.error!, isError: true),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                  onPressed: controller.busy ? null : () => controller.refresh(),
                  icon: const Icon(Icons.refresh), label: const Text('Повторить загрузку'))),
                const SizedBox(height: 16),
              ],
              if (controller.items.isEmpty && !controller.busy && controller.error == null)
                Card(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.inbox_outlined, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 24),
                    Text('Пока нет заданий', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    const Text('Когда вам назначат документ, он появится здесь. Потяните список вниз, чтобы проверить обновления.',
                      textAlign: TextAlign.center),
                  ]),
                )),
              for (final assignment in controller.items) ...[
                Card(clipBehavior: Clip.antiAlias, child: InkWell(
                  onTap: () => _open(context, assignment),
                  child: Padding(padding: const EdgeInsets.all(20), child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.description_outlined, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Назначенный документ', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Получено ${MaterialLocalizations.of(context).formatMediumDate(assignment.createdAt.toLocal())}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        const Text('Ожидает обработки'),
                        const SizedBox(height: 8),
                        Text('Задание ${assignment.id}', style: theme.textTheme.bodySmall),
                      ])),
                      const Icon(Icons.chevron_right),
                    ],
                  )),
                )),
                const SizedBox(height: 12),
              ],
              if (controller.nextAfter != null)
                OutlinedButton(onPressed: controller.busy ? null : () => controller.refresh(more: true),
                  child: const Text('Загрузить ещё')),
            ],
          ),
        ),
      ))),
    );
  }
}

class _Details extends StatefulWidget {
  const _Details({required this.controller, required this.assignment});
  final WorkspaceController controller;
  final Assignment assignment;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  late Future<DocumentDetails> _details;
  bool _preparing = false;
  int _received = 0;
  String? _pdfError;

  Future<void> _openPdf(DocumentDetails details) async {
    if (_preparing) return;
    setState(() { _preparing = true; _received = 0; _pdfError = null; });
    try {
      final path = await widget.controller.preparePdf(widget.assignment, details, (bytes) {
        if (mounted) setState(() => _received = bytes);
      });
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => PdfScreen(
        path: path, title: details.title, controller: widget.controller)));
    } catch (error) {
      if (mounted) setState(() => _pdfError = error is ApiFailure
        ? error.message : 'Не удалось открыть PDF. Повторите попытку.');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _details = widget.controller.details(widget.assignment);
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
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('Карточка документа', style: Theme.of(context).textTheme.titleLarge)),
        IconButton(tooltip: 'Закрыть карточку', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      ]),
      const SizedBox(height: 24),
      FutureBuilder<DocumentDetails>(future: _details, builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MessageCard(message: error is ApiFailure ? error.message : 'Не удалось загрузить карточку.', isError: true),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => setState(() {
              _details = widget.controller.details(widget.assignment);
            }), child: const Text('Повторить')),
          ]);
        }
        final details = snapshot.data;
        if (details == null) return const LinearProgressIndicator(semanticsLabel: 'Загрузка карточки');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(details.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text('PDF · Версия ${details.version} · ${(details.sizeBytes / 1048576).toStringAsFixed(2)} МиБ'),
          const SizedBox(height: 24),
          Text('Точная версия документа', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SelectableText(widget.assignment.versionId),
          const SizedBox(height: 16),
          Text('Контрольная сумма SHA-256', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SelectableText(details.checksum),
          const SizedBox(height: 24),
          const MessageCard(message: 'PDF сохраняется для просмотра без сети. Перед открытием проверяются размер и SHA-256. Офлайн-доступ действует до окончания текущей сессии.'),
          const SizedBox(height: 16),
          if (_pdfError != null) ...[
            MessageCard(message: _pdfError!, isError: true),
            const SizedBox(height: 16),
          ],
          if (_preparing) ...[
            LinearProgressIndicator(value: _received == 0 ? null : _received / details.sizeBytes,
              semanticsLabel: 'Скачивание и проверка PDF'),
            const SizedBox(height: 8),
            Text(_received == 0 ? 'Проверка доступа и сохранённого файла…' :
              'Получено ${(_received / 1048576).toStringAsFixed(2)} МиБ; проверка целостности…'),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(onPressed: _preparing ? null : () => _openPdf(details),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_preparing ? 'Подготовка PDF…' : 'Скачать / открыть PDF')),
        ]);
      }),
    ]),
  );
}
