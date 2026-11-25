import 'package:flutter/material.dart';

class MessageCard extends StatelessWidget {
  const MessageCard({super.key, required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline,
            color: isError ? colors.onErrorContainer : colors.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(
            color: isError ? colors.onErrorContainer : colors.onSecondaryContainer,
          ))),
        ]),
      ),
    );
  }
}
