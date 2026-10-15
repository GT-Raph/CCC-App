import 'package:flutter/material.dart';

import '../models/admin_drafts.dart';
import '../models/news.dart';
import '../services/external_actions.dart';
import '../theme/ccc_theme.dart';
import '../widgets/details_scaffold.dart';
import 'admin/admin_lists.dart';

/// A news story in full, opened from its card.
class NewsDetailsScreen extends StatelessWidget {
  const NewsDetailsScreen({required this.item, super.key});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DetailsScaffold(
      images: item.images,
      actions: [
        Expanded(
          child: Builder(
            builder: (buttonContext) => ShareButton(
              expand: true,
              onPressed: () =>
                  ExternalActions.share(buttonContext, item.shareText),
            ),
          ),
        ),
      ],
      children: [
        DetailsEyebrow(item.church),
        const SizedBox(height: 6),
        DetailsTitle(item.title),
        if (item.subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.subtitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: p.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Divider(color: p.line),
        const SizedBox(height: 18),
        Text(
          item.body,
          style: TextStyle(fontSize: 16.5, height: 1.7, color: p.text),
        ),
        StaffEditButton(
          kind: ContentKind.news,
          id: item.id,
          branchId: item.branchId,
        ),
      ],
    );
  }
}
