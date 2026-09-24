import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_blocs/app_blocs.dart';
import '../../../theme/theme.dart';

/// The app's initial route (`AppRoute.home`, see `router/app_router.dart`).
///
/// This is placeholder content, not a sample feature — the template ships
/// no product feature by design (see README.md → "Why an empty skeleton").
/// Replace this screen's body once `.agents/skills/new-feature/SKILL.md`
/// has scaffolded your first real feature, or point `AppRoute.home` at it.
///
/// It's still a real, working screen (not a stub), because it's
/// infrastructure the router needs, and it demonstrates two conventions in
/// context:
/// - the `BuildContextX` extension (`context.l10n`, `context.theme`)
///   instead of `AppLocalizations.of(context)!` / `Theme.of(context)`;
/// - reading an app-wide Cubit (`FeatureFlagCubit`, provided in
///   `lib/app.dart` at the app root) with `BlocBuilder`, as opposed to a
///   screen-scoped Cubit created locally — see
///   `.agents/skills/state-management/SKILL.md` for when to use which.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.homeScreenTitle)),
    body: Padding(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      child: Center(child: _buildBody(context)),
    ),
  );

  Widget _buildBody(BuildContext context) => BlocBuilder<FeatureFlagCubit, FeatureFlagState>(
    builder: (context, state) => Text(
      context.l10n.homeScreenPlaceholder,
      textAlign: TextAlign.center,
      style: context.theme.textTheme.bodyLarge,
    ),
  );
}
