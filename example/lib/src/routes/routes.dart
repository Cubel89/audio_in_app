import 'package:example/src/activities/loading_activity.dart';
import 'package:example/src/activities/main_activity.dart';
import 'package:flutter/material.dart';

Map<String, WidgetBuilder> getAplicationRouter(){
  return <String, WidgetBuilder>{
    'loading'                     : (BuildContext context) => LoadingActivity(),
    'main'                        : (BuildContext context) => MainActivity(),
  };
}