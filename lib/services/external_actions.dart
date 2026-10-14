import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/ccc_widgets.dart';

/// Hand-offs to other apps: the share sheet, phone, email, browser and maps.
class ExternalActions {
  static Future<void> share(BuildContext context, String text) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  static Future<void> call(BuildContext context, String phone) => _open(
    context,
    Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
    'No phone app is available.',
  );

  static Future<void> email(BuildContext context, String address) => _open(
    context,
    Uri(scheme: 'mailto', path: address),
    'No email app is available.',
  );

  static Future<void> website(BuildContext context, String site) => _open(
    context,
    Uri.parse(site.startsWith('http') ? site : 'https://$site'),
    'Could not open $site.',
  );

  static Future<void> directions(BuildContext context, String destination) =>
      _open(
        context,
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': destination,
        }),
        'Could not open maps.',
      );

  /// Turn-by-turn directions to a Google Maps place.
  static Future<void> directionsToPlace(
    BuildContext context, {
    required String placeId,
    required double latitude,
    required double longitude,
  }) => _open(
    context,
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'destination_place_id': placeId,
    }),
    'Could not open maps.',
  );

  /// Opens a Google Maps listing (photos, reviews, opening hours).
  static Future<void> openMap(BuildContext context, String mapsUri) =>
      _open(context, Uri.parse(mapsUri), 'Could not open maps.');

  static Future<void> _open(
    BuildContext context,
    Uri uri,
    String failureMessage,
  ) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!opened && context.mounted) showCccMessage(context, failureMessage);
  }
}
