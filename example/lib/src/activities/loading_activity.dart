import 'package:flutter/material.dart';

class LoadingActivity extends StatefulWidget {
  @override
  State<LoadingActivity> createState() => _LoadingActivityState();
}

class _LoadingActivityState extends State<LoadingActivity> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 1500)).then((value) =>   goToMain());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Loading Activity'),
      ),
    );
  }


  void goToMain(){
    Navigator.pushReplacementNamed(context, 'main');
  }
}