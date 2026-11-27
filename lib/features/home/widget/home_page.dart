import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/home/widget/local_proxy_hint.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hiddify/features/proxy/active/active_proxy_card.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;
    // final hasAnyProfile = ref.watch(hasAnyProfileProvider);
    final activeProfile = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        // leading: (RootScaffold.stateKey.currentState?.hasDrawer ?? false) && showDrawerButton(context)
        //     ? DrawerButton(
        //         onPressed: () {
        //           RootScaffold.stateKey.currentState?.openDrawer();
        //         },
        //       )
        //     : null,
        title: Row(
          children: [
            Assets.images.logo.svg(height: 24),
            const Gap(8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: t.common.appTitle),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // IconButton(
          //     onPressed: () => const QuickSettingsRoute().push(context),
          //     icon: const Icon(FluentIcons.options_24_filled),
          //     material: (context, platform) => MaterialIconButtonData(
          //           tooltip: t.config.quickSettings,
          //         )),
          // IconButton(
          //     onPressed: () => const AddProfileRoute().push(context),
          //     icon: const Icon(FluentIcons.add_circle_24_filled),
          //     material: (context, platform) => MaterialIconButtonData(
          //           tooltip: t.profile.add.buttonText,
          //         )),
          Semantics(
            key: const ValueKey("profile_add_button"),
            label: t.pages.profiles.add,
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
              onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
            ),
          ),
          const Gap(8),
        ],
      ),
      // The sky and the map are drawn once into their own layer: a ripple or a label changing on
      // the page no longer redraws the whole map image under it.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // perso : fond PandaVPN (dégradé doux, halo vert derrière le bouton, bambous discrets)
          RepaintBoundary(child: PandaBackground(dark: theme.brightness == Brightness.dark)),
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 600, // Set the maximum width here
                  ),
                  // The page does not move under the finger: no bounce (iOS) or stretch (Android) when it
                  // fits the screen. It still scrolls, without them, when it does not (a small screen or a
                  // large font).
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                    child: CustomScrollView(
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        // switch (activeProfile) {
                        // AsyncData(value: final profile?) =>
                        MultiSliver(
                          children: [
                            // const Gap(100),
                            switch (activeProfile) {
                              AsyncData(value: final profile?) => ProfileTile(
                                profile: profile,
                                isMain: true,
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              _ => const Text(""),
                            },
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [ConnectionButton(), ActiveProxyDelayIndicator()],
                                    ),
                                  ),
                                  ActiveProxyFooter(),
                                  Gap(32),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // AsyncData() => switch (hasAnyProfile) {
                        //     AsyncData(value: true) => const EmptyActiveProfileHomeBody(),
                        //     _ => const EmptyProfilesHomeBody(),
                        //   },
                        // AsyncError(:final error) => SliverErrorBodyPlaceholder(t.presentShortError(error)),
                        // _ => const SliverToBoxAdapter(),
                        // },
                      ],
                    ),
                  ),
                ),
              ),
              // perso : onglet « Réglages rapides » retiré (tout est dans Paramètres)
              if (false)
                Positioned(
                  right: 0,
                  left: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // tabs of either height stand on the bottom edge
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // in proxy mode, a smaller tab beside this one on how to point apps at the proxy
                      const Flexible(child: LocalProxyHint()),
                      Material(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          onTap: () => ref.read(bottomSheetsNotifierProvider.notifier).showQuickSettings(),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(t.pages.home.quickSettings),
                                const Gap(4),
                                const Icon(Icons.arrow_drop_up_rounded, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();

    return Semantics(
      label: t.common.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}


/// perso : fond de l'accueil, dessiné une fois (statique).
class PandaBackground extends StatelessWidget {
  const PandaBackground({super.key, required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    const bamboo = Color(0xFF1F8A4C);
    final base = Theme.of(context).colorScheme.surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [Color.lerp(base, bamboo, .10)!, base, Color.lerp(base, Colors.black, .25)!]
                  : [Color.lerp(base, bamboo, .07)!, base, Color.lerp(base, bamboo, .05)!],
              stops: const [0, .55, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -.15),
              radius: .7,
              colors: [
                bamboo.withValues(alpha: dark ? .16 : .10),
                bamboo.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        CustomPaint(painter: _BambooPainter(color: bamboo.withValues(alpha: dark ? .10 : .12))),
      ],
    );
  }
}

class _BambooPainter extends CustomPainter {
  const _BambooPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stalk = Paint()..color = color;
    final node = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final unit = size.width / 12;
    // (abscisse relative, hauteur relative, épaisseur)
    const stalks = [(.06, .30, 1.0), (.14, .22, .8), (.88, .26, .9), (.95, .18, .7)];
    for (final (x, h, w) in stalks) {
      final width = unit * .45 * w;
      final left = size.width * x - width / 2;
      final top = size.height * (1 - h);
      final rect = RRect.fromLTRBR(left, top, left + width, size.height + 4, Radius.circular(width / 2));
      canvas.drawRRect(rect, stalk);
      // nœuds du bambou
      for (var y = top + unit * 1.4; y < size.height; y += unit * 1.6) {
        canvas.drawLine(Offset(left - 1, y), Offset(left + width + 1, y), node);
      }
      // deux feuilles en haut de la tige
      final leafLen = unit * 1.3 * w;
      final cx = left + width / 2;
      for (final dir in [-1.0, 1.0]) {
        final path = Path()
          ..moveTo(cx, top + unit * .5)
          ..quadraticBezierTo(cx + dir * leafLen * .6, top - leafLen * .15, cx + dir * leafLen, top + unit * .1)
          ..quadraticBezierTo(cx + dir * leafLen * .5, top + unit * .55, cx, top + unit * .5)
          ..close();
        canvas.drawPath(path, stalk);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BambooPainter old) => old.color != color;
}
