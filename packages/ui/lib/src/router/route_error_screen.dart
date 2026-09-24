import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme.dart';
import 'app_router.dart';

/// Shown by `GoRouter`'s `errorBuilder` when no route matches the current
/// location (a typo'd deep link, a removed route left in a bookmark, ...).
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: _buildContent(context)));

  Widget _buildContent(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(context.l10n.routeNotFoundTitle, style: context.theme.textTheme.titleLarge),
      const SizedBox(height: AppSpacing.stackSm),
      Text(context.l10n.routeNotFoundMessage),
      const SizedBox(height: AppSpacing.stackMd),
      FilledButton(
        onPressed: () => context.go(AppRoute.home.path),
        child: Text(context.l10n.goHomeButtonLabel),
      ),
    ],
  );
}
