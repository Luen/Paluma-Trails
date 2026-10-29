import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../content/models.dart';

/// An offline photograph and its always-visible caption and attribution.
class PoiPhotoCard extends StatelessWidget {
  const PoiPhotoCard({super.key, required this.photo});

  final PoiPhoto photo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            p.posix.join('assets', 'bundle', 'photos', photo.file),
            width: double.infinity,
            fit: BoxFit.contain,
            semanticLabel: photo.caption,
            errorBuilder: (context, error, stackTrace) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Photograph unavailable. The history and caption remain available offline.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(photo.caption, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(photo.credit, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(photo.licence, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
