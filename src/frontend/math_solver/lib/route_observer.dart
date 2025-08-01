import 'package:flutter/widgets.dart';

/// Global [RouteObserver] so pages can subscribe/unsubscribe easily.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();
