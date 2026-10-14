import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    ? 'Good morning,'
    : time.hour < 17
    ? 'Good afternoon,'
    : 'Good evening,';

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
    'News by church',
    'Events near me',
    'Branches',
    'Ministries',
    'Sermons',
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
      backgroundColor: CccColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              Text(
                member.firstName,
                style: const TextStyle(
                  fontFamily: CccFonts.montserrat,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: CccColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                member.email,
                style: const TextStyle(fontSize: 14, color: CccColors.body),
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
              const SizedBox(height: 24),
              if (CccScope.of(context).staff.isStaff) ...[
                CccButton(
                  label: 'Manage church content',
                  iconGap: 10,
                  icon: const Icon(Icons.edit_note, size: 26),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminHomeScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],
              CccButton(
                label: 'Sign out',
                variant: CccButtonVariant.outlined,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = CccScope.of(context).player;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatusBar,
      // Rebuilds when a sermon is loaded or closed, not as it plays.
      child: ListenableBuilder(
        listenable: player,
        builder: (context, body) => Scaffold(
          backgroundColor: CccColors.background,
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
      ),
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
    return TextButton.icon(
      onPressed: () => openEditor(context, kind),
      style: TextButton.styleFrom(
        foregroundColor: CccColors.ink,
        backgroundColor: CccColors.primaryTint,
        shape: const StadiumBorder(side: BorderSide(color: CccColors.primary)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        minimumSize: const Size(0, 36),
        // A 48px touch target around the smaller pill.
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Text(
        'New ${kind.noun}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
            child: GreetingHeader(
              greeting: greetingFor(DateTime.now()),
              name: widget.member?.firstName ?? 'Guest',
              onAvatarTap: _openAccount,
              onSettingsTap: _openAccount,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            sliver: SliverToBoxAdapter(
              child: CccSearchField(
                controller: searchController,
                onChanged: (value) => setState(() => query = value),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(child: SectionTitle(_titles[tab])),
                  ?_newButton(context),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 34 + bottom),
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
          _ListeningBranch(branch: branch, onChange: _chooseBranch),
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
          _ListeningBranch(branch: branch, onChange: _chooseBranch),
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
    separatorBuilder: (_, _) => const SizedBox(height: 20),
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
            const Text(
              'Branch details and photos from Google Maps',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: CccColors.body),
            ),
        ];
        return SliverList.separated(
          itemCount: items.length,
          itemBuilder: (_, index) => items[index],
          separatorBuilder: (_, _) => const SizedBox(height: 20),
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
          _ListeningBranch(branch: branch, onChange: _chooseBranch),
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
          separatorBuilder: (_, _) => const SizedBox(height: 20),
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
          _ListeningBranch(branch: branch, onChange: _chooseBranch),
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
          separatorBuilder: (_, index) =>
              SizedBox(height: index == 0 ? 16 : 12),
        );
      },
    );
  }
}

/// The branch whose sermons or events are listed, with a way to switch. With
/// no branch chosen, the events are the all-branch ones.
class _ListeningBranch extends StatelessWidget {
  const _ListeningBranch({required this.branch, required this.onChange});

  final ChurchBranch? branch;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 4, 4, 4),
      decoration: BoxDecoration(
        color: CccColors.paper,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.church, size: 20, color: CccColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              branch?.name ?? 'All branches',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: CccColors.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: CccColors.navy,
              minimumSize: const Size(64, 44),
            ),
            child: Text(
              branch == null ? 'Choose' : 'Change',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
    return Row(
      children: [
        const Icon(Icons.church, size: 22, color: CccColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your branch',
                style: TextStyle(fontSize: 13, color: CccColors.body),
              ),
              const SizedBox(height: 2),
              Text(
                branch?.name ?? 'Not chosen yet',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: CccColors.ink,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onChange,
          style: TextButton.styleFrom(
            foregroundColor: CccColors.navy,
            minimumSize: const Size(64, 44),
          ),
          child: Text(
            branch == null ? 'Choose' : 'Change',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: CccColors.inactive),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: CccColors.body),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: CccColors.body),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            CccButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: CccButtonVariant.outlined,
              width: 188,
              height: 44,
              fontSize: 14,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
      decoration: BoxDecoration(
        color: CccColors.paper,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: CccColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                height: 18 / 14,
                color: CccColors.body,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CccButton(
            label: action,
            onPressed: onEnable,
            width: 84,
            height: 36,
            fontSize: 14,
          ),
        ],
      ),
    );
  }
}
