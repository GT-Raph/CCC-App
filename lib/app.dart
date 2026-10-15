import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/places_service.dart';
import 'services/sermon_service.dart';
import 'state/branch_directory.dart';
import 'state/ccc_state.dart';
import 'state/sermon_library.dart';
import 'theme/ccc_theme.dart';

class CccApp extends StatefulWidget {
  const CccApp({
    this.initialMember,
    this.googleMapsApiKey,
    this.state,
    super.key,
  });

  /// The member restored from a saved session, or null to start as a visitor.
  final Member? initialMember;

  /// Enables the church branches on the Church tab (Places + Routes APIs).
  final String? googleMapsApiKey;

  /// Replaces the app's own state, so tests can use fake data sources.
  @visibleForTesting
  final CccState? state;

  @override
  State<CccApp> createState() => _CccAppState();
}

class _CccAppState extends State<CccApp> {
  /// Supabase's branch list feeds both the branch picker and the Church tab.
  late final churchData = SermonService.configured();

  late final state = widget.state ?? _create();

  CccState _create() => CccState(
    branches: BranchDirectory(
      places: (widget.googleMapsApiKey ?? '').isEmpty
          ? null
          : PlacesService(apiKey: widget.googleMapsApiKey!),
      listedBranches: churchData?.branches,
    ),
    sermons: SermonLibrary(source: churchData),
  );

  @override
  void dispose() {
    if (widget.state == null) state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CccScope(
      state: state,
      child: MaterialApp(
        title: 'CCC',
        debugShowCheckedModeBanner: false,
        // Light or dark with the phone.
        theme: buildCccTheme(),
        darkTheme: buildCccTheme(Brightness.dark),
        // Status bar icons that read on the current appearance. Screens with
        // their own colours (the welcome screen) set their own.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: cccSystemBars(Theme.of(context).brightness),
          child: child!,
        ),
        home: SplashScreen(member: widget.initialMember),
      ),
    );
  }
}
