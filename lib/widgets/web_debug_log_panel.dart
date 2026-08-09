import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/web_debug_log_service.dart';

class WebDebugLogPanel extends StatelessWidget {
  const WebDebugLogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final service = WebDebugLogService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final hasLogs = service.logs.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black87,
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      hasLogs ? service.text : 'Aguardando tentativa de login...',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: hasLogs
                      ? () async {
                          await Clipboard.setData(
                            ClipboardData(text: service.text),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Logs copiados para a área de transferência.',
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar logs'),
                ),
                TextButton.icon(
                  onPressed: hasLogs ? service.clear : null,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Limpar logs'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
