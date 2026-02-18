import 'package:example/src/activities/loading_activity.dart';
import 'package:example/src/activities/main_activity.dart';
import 'package:flutter/material.dart';

Map<String, WidgetBuilder> getApplicationRouter() {
  return <String, WidgetBuilder>{
    'loading': (BuildContext context) => const LoadingActivity(),
    'main': (BuildContext context) => const MainActivity(),
  };
}
