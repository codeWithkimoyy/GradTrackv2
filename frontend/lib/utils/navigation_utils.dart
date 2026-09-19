import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';

/// Pops the current route. When there is nothing to pop (e.g. a web deep
/// link opened directly in a fresh tab), goes to the role-aware dashboard
/// instead of throwing "There is nothing to pop".
void popOrGoHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.dashboard);
  }
}
