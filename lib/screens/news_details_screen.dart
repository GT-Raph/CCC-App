import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_drafts.dart';
import '../models/news.dart';
import '../services/external_actions.dart';
import '../theme/ccc_theme.dart';
import '../widgets/cards.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/media.dart';
import 'admin/admin_lists.dart';

/// Opened from a news card's "Details"; follows the event details layout.
class NewsDetailsScreen extends StatelessWidget {
  const NewsDetailsScreen({required this.item, super.key});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatusBar,
      child: Scaffold(
        backgroundColor: CccColors.background,
        body: Column(
          children: [
            const DetailsHeader(title: 'Details'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 14 + bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ImageCarousel(images: item.images, height: 200),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: CccColors.navy,
                            ),
                          ),
                          if (item.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1,
                                color: CccColors.body,
                              ),
                            ),
                          ],
                          const SizedBox(height: 15),
                          IconTextRow(
                            icon: Icons.church,
                            iconSize: 18,
                            text: item.church,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 21 / 16,
                              color: CccColors.body,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            item.body,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 21 / 16,
                              color: CccColors.body,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Builder(
                            builder: (buttonContext) => CccButton(
                              label: 'Share',
                              variant: CccButtonVariant.outlined,
                              iconGap: 19,
                              icon: const Icon(Icons.share, size: 31),
                              onPressed: () => ExternalActions.share(
                                buttonContext,
                                item.shareText,
                              ),
                            ),
                          ),
                          StaffEditButton(
                            kind: ContentKind.news,
                            id: item.id,
                            branchId: item.branchId,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
