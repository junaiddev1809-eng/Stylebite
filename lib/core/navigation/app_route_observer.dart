import 'package:flutter/widgets.dart';

/// Shared route observer for screens that need to pause work when covered by
/// another full-screen route.
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();
