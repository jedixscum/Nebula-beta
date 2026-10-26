import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/starfield.dart';
import '../core/theme.dart';
import '../data/theme_settings.dart';
import '../l10n/app_localizations.dart';
import 'catalog_browser_screen.dart';
import 'shell.dart';
import 'widgets.dart';

/// Dedicated Android TV shell.
///
/// This is intentionally separate from the phone shell: it uses large hit
/// targets, a persistent navigation rail, and explicit D-pad focus styling.
class TvShell extends ConsumerStatefulWidget {
  const TvShell({super.key});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  int _selected = 0;

  static const _titles = <String>[
    'Home',
    'Movies',
    'TV Shows',
    'Library',
    'Profile',
  ];

  void _select(int index) {
    if (_selected == index) return;
    setState(() => _selected = index);
  }

  // Do not make this list const: CatalogGrid's constructor is not const.
  List<Widget> _pages() {
    return <Widget>[
      const TvHomePage(),
      CatalogGrid(type: MediaType.movie),
      CatalogGrid(type: MediaType.show),
      const LibraryPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final settings = ref.watch(themeSettingsProvider);
    final labels = <String>[
      localizations.home,
      localizations.movies,
      localizations.tvShows,
      localizations.library,
      'Profile',
    ];

    return Starfield(
      enabled: settings.starfieldEnabled,
      child: Scaffold(
        backgroundColor: settings.background,
        body: SafeArea(
          child: Row(
            children: <Widget>[
              _TvNavigation(
                selected: _selected,
                labels: labels,
                onSelected: _select,
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _TvHeader(
                      title: _titles[_selected],
                      onSearch: () => context.push('/search'),
                      onSettings: () => context.push('/appearance'),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: KeyedSubtree(
                          key: ValueKey<int>(_selected),
                          child: _pages()[_selected],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvNavigation extends StatelessWidget {
  const _TvNavigation({
    required this.selected,
    required this.labels,
    required this.onSelected,
  });

  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  static const _icons = <IconData>[
    Icons.home_rounded,
    Icons.movie_rounded,
    Icons.live_tv_rounded,
    Icons.bookmark_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.96),
        border: Border(
          right: BorderSide(color: nebulaViolet.withOpacity(0.22)),
        ),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 30),
          const _TvBrand(),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              itemCount: labels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _TvNavButton(
                  label: labels[index],
                  icon: _icons[index],
                  selected: selected == index,
                  autofocus: index == 0 && selected == 0,
                  onPressed: () => onSelected(index),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'D-PAD  •  OK  •  BACK',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvBrand extends StatelessWidget {
  const _TvBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: <Color>[nebulaViolet, nebulaCyan],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: nebulaViolet, blurRadius: 22),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: spaceBlack,
            size: 36,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'NEBULA',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
        ),
        const SizedBox(height: 3),
        const Text(
          'ANDROID TV',
          style: TextStyle(
            color: nebulaCyan,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

class _TvNavButton extends StatefulWidget {
  const _TvNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.autofocus,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  State<_TvNavButton> createState() => _TvNavButtonState();
}

class _TvNavButtonState extends State<_TvNavButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || focused;

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onFocusChange: (value) => setState(() => focused = value),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: widget.selected
                ? nebulaViolet.withOpacity(0.25)
                : focused
                    ? nebulaCyan.withOpacity(0.16)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused
                  ? nebulaCyan
                  : widget.selected
                      ? nebulaViolet.withOpacity(0.75)
                      : Colors.transparent,
              width: focused ? 3 : 1,
            ),
            boxShadow: focused
                ? <BoxShadow>[
                    BoxShadow(
                      color: nebulaCyan.withOpacity(0.24),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                widget.icon,
                size: 30,
                color: active ? nebulaCyan : Colors.white60,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontSize: 17,
                    fontWeight:
                        active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (widget.selected)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: nebulaCyan,
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvHeader extends StatelessWidget {
  const _TvHeader({
    required this.title,
    required this.onSearch,
    required this.onSettings,
  });

  final String title;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 24, 38, 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          _TvHeaderButton(
            icon: Icons.search_rounded,
            label: 'Search',
            onPressed: onSearch,
          ),
          const SizedBox(width: 12),
          _TvHeaderButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _TvHeaderButton extends StatefulWidget {
  const _TvHeaderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_TvHeaderButton> createState() => _TvHeaderButtonState();
}

class _TvHeaderButtonState extends State<_TvHeaderButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (value) => setState(() => focused = value),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: focused
                ? nebulaCyan.withOpacity(0.18)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focused ? nebulaCyan : Colors.white12,
              width: focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                widget.icon,
                size: 23,
                color: focused ? nebulaCyan : Colors.white70,
              ),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TvHomePage extends StatelessWidget {
  const TvHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(34, 8, 34, 40),
      children: <Widget>[
        _TvHero(onSearch: () => context.push('/search')),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _TvHero extends StatelessWidget {
  const _TvHero({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: <Color>[
            nebulaViolet.withOpacity(0.30),
            nebulaCyan.withOpacity(0.08),
          ],
        ),
        border: Border.all(color: nebulaViolet.withOpacity(0.25)),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'WELCOME TO NEBULA',
                  style: TextStyle(
                    color: nebulaCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Your entertainment,\nmade for the big screen.',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Use the D-pad to browse and press OK to select.',
                  style: TextStyle(color: Colors.white70, fontSize: 17),
                ),
              ],
            ),
          ),
          const SizedBox(width: 30),
          _TvHeaderButton(
            icon: Icons.search_rounded,
            label: 'Search',
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}
