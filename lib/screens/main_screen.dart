import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/admin_drafts.dart';
import '../models/church_branch.dart';
import '../models/event.dart';
import '../models/live_stream.dart';
import '../models/news.dart';
import '../models/sermon.dart';
import '../navigation.dart';
import '../services/auth_service.dart';
import '../services/external_actions.dart';
import '../services/location_service.dart';
import '../state/branch_directory.dart';
import '../state/branch_feed.dart';
import '../state/ccc_state.dart';
import '../state/sermon_library.dart';
import '../theme/ccc_theme.dart';
import '../widgets/branch_picker.dart';
import '../widgets/cards.dart';
import '../widgets/ccc_widgets.dart';
import '../widgets/sermon_player_view.dart';
import 'admin/admin_lists.dart';
import 'event_details_screen.dart';
import 'ministry_details_screen.dart';

String greetingFor(DateTime time) => time.hour < 12
    ? 'Good morning'
    : time.hour < 17
    ? 'Good afternoon'
    : 'Good evening';

/// "Home", "Event" and "Church Community" frames: one screen with the photo
/// header, the Home / Events / Church / Ministries / Sermons switcher, search
/// and the card list. Without a [member] it is "Home Without Login".
class MainScreen extends StatefulWidget {
  const MainScreen({
    this.member,
    this.promptGuestLogin = false,
    this.initialTab = 0,
    super.key,
  });

  final Member? member;

  /// Show the "Login after Home" sheet shortly after a guest arrives.
  final bool promptGuestLogin;
  final int initialTab;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _titles = [
    'News',
    'Events',
    'Branches',
    'Ministries',
    'Sermons',
  ];
  static const _searchHints = [
    'Search news',
    'Search events',
    'Search branches',
    'Search ministries',
    'Search sermons',
  ];
  static const _homeTab = 0;
  static const _eventsTab = 1;
  static const _churchTab = 2;
  static const _ministriesTab = 3;
  static const _sermonsTab = 4;

  late int tab = widget.initialTab;
  final searchController = TextEditingController();
  final scroll = ScrollController();

  /// Where each section was scrolled to, restored when it's shown again.
  final scrollOffsets = <int, double>{};
  String query = '';
  late final AppLifecycleListener lifecycle;

  bool get isGuest => widget.member == null;

  @override
  void initState() {
    super.initState();
    // Coming back from the location settings screen refreshes distances.
    lifecycle = AppLifecycleListener(onResume: _refreshDistances);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
    if (widget.promptGuestLogin && isGuest) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
        showLoginPrompt(context);
      });
    }
  }

  @override
  void dispose() {
    lifecycle.dispose();
    searchController.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == tab) {
      // Tapping the current section again goes back to its top.
      if (scroll.hasClients && scroll.offset > 0) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (scroll.hasClients) scrollOffsets[tab] = scroll.offset;
    setState(() {
      tab = index;
      query = '';
      searchController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      final position = scroll.position;
      scroll.jumpTo(
        (scrollOffsets[index] ?? 0).clamp(0.0, position.maxScrollExtent),
      );
    });
    _loadTab(index);
  }

  void _loadTab(int index) {
    final state = CccScope.of(context);
    switch (index) {
      case _homeTab:
        unawaited(state.news.ensureLoaded());
      case _eventsTab:
        unawaited(state.events.ensureLoaded());
      case _churchTab:
        unawaited(state.branches.ensureLoaded());
      case _ministriesTab:
        unawaited(state.ministries.ensureLoaded());
      case _sermonsTab:
        unawaited(state.sermons.ensureLoaded());
    }
  }

  /// Sets up the member's (or guest's) branch for the Sermons tab, and asks
  /// members who don't have a branch yet to choose one.
  Future<void> _startListening() async {
    if (!mounted) return;
    final state = CccScope.of(context);
    final library = state.sermons;
    unawaited(state.reminders.restore());
    unawaited(state.ministries.useMember(widget.member));
    unawaited(state.staff.useMember(widget.member));
    await library.useListener(widget.member);
    if (!mounted) return;
    _loadTab(tab);
    if (widget.member == null ||
        library.branch != null ||
        !library.isConfigured) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    await _chooseBranch(firstTime: true);
  }

  Future<void> _chooseBranch({bool firstTime = false}) async {
    final library = CccScope.of(context).sermons;
    final chosen = await showBranchPicker(
      context,
      selected: library.branch,
      message: firstTime
          ? "You'll hear your branch's sermons and those for every branch. "
                'You can change your branch later from your account.'
          : null,
    );
    if (chosen == null || !mounted) return;
    try {
      await library.chooseBranch(chosen);
      if (mounted && !isGuest) {
        showCccMessage(context, 'Your branch is now ${chosen.name}.');
      }
    } catch (_) {
      if (mounted) {
        showCccMessage(
          context,
          "Couldn't save your branch. Check your connection and try again.",
        );
      }
    }
  }

  void _playSermon(Sermon sermon, ChurchBranch branch) {
    final player = CccScope.of(context).player;
    if (player.sermon?.id == sermon.id) {
      player.toggle();
    } else {
      player.play(
        sermon,
        branchName: sermon.forAllBranches ? NewsItem.churchName : branch.name,
      );
    }
  }

  void _refreshDistances() {
    if (!mounted || tab != _churchTab) return;
    final branches = CccScope.of(context).branches;
    if (branches.locationAccess != LocationAccess.granted) {
      branches.refreshDistances();
    }
  }

  void _eventAction(Event event, LiveStream? live) {
    if (live != null) {
      // Anyone can watch; no need to log in.
      CccNavigation.openLiveStream(
        context,
        live,
        branchName: event.church,
        event: event,
      );
      return;
    }
    remindOrJoin(context, event, member: widget.member);
  }

  void _openAccount() {
    final member = widget.member;
    if (member == null) {
      showLoginPrompt(context);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Avatar(member: member, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.firstName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              letterSpacing: -0.3,
                              color: p.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            member.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListenableBuilder(
                  listenable: CccScope.of(context).sermons,
                  builder: (_, _) => _AccountBranch(
                    branch: CccScope.of(context).sermons.branch,
                    onChange: () {
                      Navigator.pop(sheetContext);
                      _chooseBranch();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (CccScope.of(context).staff.isStaff) ...[
                  CccButton(
                    label: 'Manage church content',
                    variant: CccButtonVariant.tonal,
                    icon: const Icon(Icons.edit_note),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminHomeScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                CccButton(
                  label: 'Sign out',
                  variant: CccButtonVariant.outlined,
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final state = CccScope.of(context);
                    final player = state.player;
                    await AuthService.signOut();
                    await state.ministries.useMember(null);
                    await state.staff.useMember(null);
                    await state.sermons.useListener(null);
                    await player.close();
                    if (mounted) CccNavigation.openWelcome(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = CccScope.of(context).player;
    // Rebuilds when a sermon is loaded or closed, not as it plays.
    return ListenableBuilder(
      listenable: player,
      builder: (context, body) => Scaffold(
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.sermon != null) const MiniPlayer(),
            CccNavigationBar(selectedIndex: tab, onSelected: _selectTab),
          ],
        ),
        body: body,
      ),
      child: Builder(builder: _content),
    );
  }

  /// Staff add news, events, ministries and sermons from their tab.
  Widget? _newButton(BuildContext context) {
    final staff = CccScope.of(context).staff;
    final kind = switch (tab) {
      _homeTab => ContentKind.news,
      _eventsTab => ContentKind.events,
      _ministriesTab => ContentKind.ministries,
      _sermonsTab => ContentKind.sermons,
      _ => null,
    };
    if (!staff.isStaff || kind == null) return null;
    final p = context.palette;
    return TextButton.icon(
      onPressed: () => openEditor(context, kind),
      style: TextButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.accentTint,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        minimumSize: const Size(0, 44),
      ),
      icon: Icon(Icons.add, size: 18, color: p.accentText),
      label: Text(
        'New ${kind.noun}',
        style: const TextStyle(
          fontFamily: CccFonts.openSans,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return RefreshIndicator(
      color: CccColors.primary,
      notificationPredicate: (notification) => notification.depth == 0,
      onRefresh: () => switch (tab) {
        _homeTab => CccScope.of(context).news.refresh(),
        _eventsTab => CccScope.of(context).events.refresh(),
        _churchTab => CccScope.of(context).branches.refresh(),
        _ministriesTab => CccScope.of(context).ministries.refresh(),
        _ => CccScope.of(context).sermons.refresh(),
      },
      child: CustomScrollView(
        controller: scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              greeting: [
                greetingFor(DateTime.now()),
                ?widget.member?.firstName,
              ].join(', '),
              title: _titles[tab],
              member: widget.member,
              onAccount: _openAccount,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: CccSearchField(
                controller: searchController,
                hint: _searchHints[tab],
                onChanged: (value) => setState(() => query = value),
              ),
            ),
          ),
          if (tab != _churchTab)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: ListenableBuilder(
                  listenable: CccScope.of(context).sermons,
                  builder: (context, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: _BranchChip(
                          branch: CccScope.of(context).sermons.branch,
                          onTap: _chooseBranch,
                        ),
                      ),
                      if (_newButton(context) case final button?) ...[
                        const SizedBox(width: 12),
                        button,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + bottom),
            sliver: switch (tab) {
              _homeTab => _news(context),
              _eventsTab => _events(context),
              _churchTab => _branches(context),
              _ministriesTab => _ministries(context),
              _ => _sermons(context),
            },
          ),
        ],
      ),
    );
  }
}

extension on _MainScreenState {
  /// Home tab: the listener's branch news and the church-wide news.
  Widget _news(BuildContext context) {
    final state = CccScope.of(context);
    final feed = state.news;
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        final notice = _feedNotice(
          feed,
          icon: Icons.article_outlined,
          unavailable: 'News is not available yet.',
          loading: 'Loading news',
          photo: true,
        );
        if (notice != null) return notice;

        final branch = state.sermons.branch;
        final visible = feed.items
            .where((item) => item.matches(query))
            .toList();
        return _feedList([
          if (visible.isEmpty)
            _TabNotice(
              icon: Icons.article_outlined,
              message: query.isEmpty
                  ? 'No news yet.'
                  : 'Nothing matches “$query”.',
              detail: query.isEmpty && branch == null
                  ? 'Choose your branch to see its news as well as the '
                        'church-wide news.'
                  : null,
            )
          else
            for (final item in visible)
              NewsCard(
                item: item,
                onDetails: () => CccNavigation.openNews(context, item),
                onShare: () => ExternalActions.share(context, item.shareText),
              ),
        ]);
      },
    );
  }

  /// Ministries tab: the listener's branch ministries and the church-wide
  /// ones, with Join / Joined for members.
  Widget _ministries(BuildContext context) {
    final state = CccScope.of(context);
    final directory = state.ministries;
    return ListenableBuilder(
      listenable: directory,
      builder: (context, _) {
        final notice = _feedNotice(
          directory,
          icon: Icons.people_outline,
          unavailable: 'Ministries are not available yet.',
          loading: 'Loading ministries',
        );
        if (notice != null) return notice;

        final branch = state.sermons.branch;
        final visible = directory.items
            .where((ministry) => ministry.matches(query))
            .toList();
        return _feedList([
          if (visible.isEmpty)
            _TabNotice(
              icon: Icons.people_outline,
              message: query.isEmpty
                  ? 'No ministries yet.'
                  : 'Nothing matches “$query”.',
              detail: query.isEmpty && branch == null
                  ? "Choose your branch to see its ministries as well as "
                        'the church-wide ones.'
                  : null,
            )
          else
            for (final ministry in visible)
              MinistryCard(
                ministry: ministry,
                joined: directory.hasJoined(ministry.id),
                onOpen: () => CccNavigation.openMinistry(
                  context,
                  ministry,
                  member: widget.member,
                ),
                onJoin: () => joinOrLeaveMinistry(
                  context,
                  ministry,
                  member: widget.member,
                ),
              ),
        ]);
      },
    );
  }

  /// The not-set-up, loading and error states of a Supabase-backed tab, or
  /// null once its list is ready.
  Widget? _feedNotice(
    BranchFeed<Object?> feed, {
    required IconData icon,
    required String unavailable,
    required String loading,
    bool photo = false,
  }) {
    return switch (feed.status) {
      FeedStatus.notConfigured => SliverToBoxAdapter(
        child: _TabNotice(
          icon: icon,
          message: unavailable,
          detail: kDebugMode
              ? 'Supabase is not configured (see README).'
              : null,
        ),
      ),
      FeedStatus.loading => SliverToBoxAdapter(
        child: SkeletonList(label: loading, photo: photo),
      ),
      FeedStatus.failed => SliverToBoxAdapter(
        child: _TabNotice(
          icon: feed.setupMissing ? icon : Icons.wifi_off_rounded,
          message: feed.error!,
          detail: kDebugMode && feed.setupMissing
              ? 'Run supabase/schema.sql in Supabase (see README).'
              : null,
          actionLabel: feed.setupMissing ? null : 'Try again',
          onAction: feed.refresh,
        ),
      ),
      FeedStatus.ready => null,
    };
  }

  Widget _feedList(List<Widget> items) => SliverList.separated(
    itemCount: items.length,
    itemBuilder: (_, index) => items[index],
    separatorBuilder: (_, _) => const SizedBox(height: 14),
  );
}

extension on _MainScreenState {
  /// Church tab: the church's branches from Google Maps.
  Widget _branches(BuildContext context) {
    final directory = CccScope.of(context).branches;
    return ListenableBuilder(
      listenable: directory,
      builder: (context, _) {
        final status = directory.status;
        if (status == BranchStatus.notConfigured) {
          return const SliverToBoxAdapter(
            child: _TabNotice(
              icon: Icons.map_outlined,
              message: 'Branch locations are not available yet.',
              detail: kDebugMode
                  ? 'Add GOOGLE_MAPS_API_KEY to .env (see README).'
                  : null,
            ),
          );
        }
        if (status == BranchStatus.failed) {
          return SliverToBoxAdapter(
            child: _TabNotice(
              icon: Icons.wifi_off_rounded,
              message: directory.error!,
              actionLabel: 'Try again',
              onAction: directory.refresh,
            ),
          );
        }
        if (directory.branches.isEmpty && status != BranchStatus.ready) {
          return const SliverToBoxAdapter(
            child: SkeletonList(
              label: 'Finding branches on Google Maps',
              photo: true,
            ),
          );
        }

        final access = directory.locationAccess;
        final visible = directory.branches
            .where((branch) => branch.matches(query))
            .toList();
        final items = <Widget>[
          if (access != null && access != LocationAccess.granted)
            _LocationBanner(access: access, onEnable: directory.enableLocation),
          if (visible.isEmpty)
            _TabNotice(
              icon: Icons.church_outlined,
              message: query.isEmpty
                  ? 'No branches found on Google Maps.'
                  : 'Nothing matches “$query”.',
            ),
          for (final branch in visible)
            BranchCard(
              branch: branch,
              photoUrl: directory.places!.photoUrl,
              onOpen: () => ExternalActions.openMap(context, branch.mapsUri),
              onDirections: () => ExternalActions.directionsToPlace(
                context,
                placeId: branch.id,
                latitude: branch.latitude,
                longitude: branch.longitude,
              ),
            ),
          if (directory.branches.isNotEmpty)
            Text(
              'Branch details and photos from Google Maps',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.palette.textMuted),
            ),
        ];
        return SliverList.separated(
          itemCount: items.length,
          itemBuilder: (_, index) => items[index],
          separatorBuilder: (_, _) => const SizedBox(height: 14),
        );
      },
    );
  }
}

extension on _MainScreenState {
  /// Events tab: the listener's branch events and the all-branch ones, with
  /// any live stream from their branch.
  Widget _events(BuildContext context) {
    final state = CccScope.of(context);
    final board = state.events;
    return ListenableBuilder(
      listenable: Listenable.merge([board, state]),
      builder: (context, _) {
        final notice = _feedNotice(
          board,
          icon: Icons.event_outlined,
          unavailable: 'Events are not available yet.',
          loading: 'Loading events',
          photo: true,
        );
        if (notice != null) return notice;

        final branch = state.sermons.branch;
        final liveNow = board.branchLiveNow;
        final visible = board.events
            .where((event) => event.matches(query))
            .toList();
        final items = <Widget>[
          if (liveNow != null && branch != null && query.isEmpty)
            LiveNowCard(
              stream: liveNow,
              branchName: branch.name,
              onWatch: () => CccNavigation.openLiveStream(
                context,
                liveNow,
                branchName: branch.name,
              ),
            ),
          if (visible.isEmpty)
            _TabNotice(
              icon: Icons.event_outlined,
              message: query.isEmpty
                  ? 'No upcoming events.'
                  : 'Nothing matches “$query”.',
              detail: query.isEmpty && branch == null
                  ? 'Choose your branch to see its events as well as the '
                        'ones for all branches.'
                  : null,
            )
          else
            for (final event in visible)
              EventCard(
                event: event,
                reminded: state.reminders.isSet(event.id),
                live: board.liveFor(event),
                onOpen: () => CccNavigation.openEvent(
                  context,
                  event,
                  member: widget.member,
                ),
                onAction: () => _eventAction(event, board.liveFor(event)),
                onShare: () => ExternalActions.share(context, event.shareText),
              ),
        ];
        return SliverList.separated(
          itemCount: items.length,
          itemBuilder: (_, index) => items[index],
          separatorBuilder: (_, _) => const SizedBox(height: 14),
        );
      },
    );
  }

  /// Sermons tab: the listener's branch and its sermons, newest first.
  Widget _sermons(BuildContext context) {
    final state = CccScope.of(context);
    final library = state.sermons;
    final player = state.player;
    return ListenableBuilder(
      listenable: Listenable.merge([library, player]),
      builder: (context, _) {
        final status = library.status;
        if (status == SermonStatus.notConfigured) {
          return const SliverToBoxAdapter(
            child: _TabNotice(
              icon: Icons.headphones_outlined,
              message: 'Sermons are not available yet.',
              detail: kDebugMode
                  ? 'Supabase is not configured (see README).'
                  : null,
            ),
          );
        }
        final branch = library.branch;
        if (branch == null) {
          return SliverToBoxAdapter(
            child: _TabNotice(
              icon: Icons.church_outlined,
              message: 'Choose your branch to hear its sermons.',
              actionLabel: 'Choose branch',
              onAction: _chooseBranch,
            ),
          );
        }

        final visible = library.sermons
            .where((sermon) => sermon.matches(query))
            .toList();
        final items = <Widget>[
          if (status == SermonStatus.loading)
            const SkeletonList(label: 'Loading sermons', count: 4)
          else if (status == SermonStatus.failed)
            _TabNotice(
              icon: library.setupMissing
                  ? Icons.headphones_outlined
                  : Icons.wifi_off_rounded,
              message: library.error!,
              detail: kDebugMode && library.setupMissing
                  ? 'Run supabase/schema.sql in Supabase (see README).'
                  : null,
              actionLabel: library.setupMissing ? null : 'Try again',
              onAction: library.refresh,
            )
          else if (visible.isEmpty)
            _TabNotice(
              icon: Icons.headphones_outlined,
              message: query.isEmpty
                  ? 'No sermons from ${branch.name} yet.'
                  : 'Nothing matches “$query”.',
              detail: query.isEmpty
                  ? 'New sermons appear here once your branch uploads them.'
                  : null,
            )
          else
            for (final sermon in visible)
              SermonCard(
                sermon: sermon,
                playback: playbackOf(player, sermon),
                position: player.sermon?.id == sermon.id
                    ? player.position
                    : null,
                length: player.duration,
                onTap: () => _playSermon(sermon, branch),
              ),
        ];
        return SliverList.separated(
          itemCount: items.length,
          itemBuilder: (_, index) => items[index],
          separatorBuilder: (_, _) => const SizedBox(height: 12),
        );
      },
    );
  }
}

/// Greeting, the tab's title and the account button.
class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.title,
    required this.member,
    required this.onAccount,
  });

  final String greeting;
  final String title;
  final Member? member;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 14, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: p.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.8,
                      color: p.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Account',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onAccount,
              radius: 26,
              child: SizedBox.square(
                dimension: 52,
                child: Center(child: _Avatar(member: member, size: 40)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The member's initial on gold, or a person outline for a guest.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.member, required this.size});

  final Member? member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = member?.firstName.trim() ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: member == null ? p.surfaceAlt : CccColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: name.isEmpty
          ? Icon(Icons.person_outline, size: size * 0.55, color: p.text)
          : Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                height: 1,
                color: CccColors.onPrimary,
              ),
            ),
    );
  }
}

/// The branch whose news, events, ministries and sermons are listed. With no
/// branch chosen, the lists show what's shared with every branch.
class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.branch, required this.onTap});

  final ChurchBranch? branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: 'Change branch',
      child: Material(
        color: p.surface,
        shape: StadiumBorder(side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.church_outlined, size: 17, color: p.accentText),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      branch?.name ?? 'All branches',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 20, color: p.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Your branch" row in the account sheet.
class _AccountBranch extends StatelessWidget {
  const _AccountBranch({required this.branch, required this.onChange});

  final ChurchBranch? branch;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CccCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      child: Row(
        children: [
          Icon(Icons.church_outlined, size: 20, color: p.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your branch',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: p.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  branch?.name ?? 'Not chosen yet',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: p.text,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: p.accentText,
              minimumSize: const Size(64, 44),
            ),
            child: Text(
              branch == null ? 'Choose' : 'Change',
              style: const TextStyle(
                fontFamily: CccFonts.openSans,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabNotice extends StatelessWidget {
  const _TabNotice({
    required this.icon,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: p.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: p.text,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: p.textSecondary,
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            CccButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: CccButtonVariant.outlined,
              width: 180,
              height: 44,
              fontSize: 15,
            ),
          ],
        ],
      ),
    );
  }
}

/// Invites the member to share their location so branches can be sorted by
/// distance.
class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.access, required this.onEnable});

  final LocationAccess access;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (message, action) = switch (access) {
      LocationAccess.serviceOff => (
        'Turn on location to see the nearest branches and travel times.',
        'Turn on',
      ),
      LocationAccess.deniedForever => (
        'Allow location in Settings to see the nearest branches.',
        'Settings',
      ),
      _ => (
        'Share your location to see the nearest branches and travel times.',
        'Allow',
      ),
    };
    return CccCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Icon(Icons.near_me_outlined, color: p.accentText, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: p.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CccButton(
            label: action,
            onPressed: onEnable,
            width: 92,
            height: 40,
            fontSize: 14,
          ),
        ],
      ),
    );
  }
}
