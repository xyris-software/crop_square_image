import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:crop_square_image/crop_square_image.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _currentTemperature = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    String currentTemperature;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await CropSquareImage.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    try {
      currentTemperature = await CropSquareImage.currentTemperature;
    } on PlatformException {
      currentTemperature = 'Failed to get current temperature.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      _currentTemperature = currentTemperature;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Center(child: Text('Running on: $_platformVersion\n')),
            Center(child: Text('Current temperature: $_currentTemperature\n')),
          ],
        ),
      ),
    );
  }
}
