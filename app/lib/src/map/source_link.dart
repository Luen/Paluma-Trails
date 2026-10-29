import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// An attributed source whose text remains readable without a connection.
class SourceLink extends StatelessWidget {
  const SourceLink({
    super.key,
    required this.label,
    required this.url,
    this.launch = launchUrl,
  });

  final String label;
  final String? url;
  final Future<bool> Function(Uri) launch;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SelectableText(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          alignment: AlignmentDirectional.centerStart,
        ),
        onPressed: () async {
          var opened = false;
          try {
            opened = await launch(uri);
          } catch (_) {
            // A missing browser/plugin must not make the offline page fail.
          }
          if (!opened && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not open the source. Check your connection and try again.',
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.open_in_new, size: 20),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Text(
              'Read online · ${uri.host}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
