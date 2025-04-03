## Connecting Firebase with Flutter 

Make sure you install command line tools only from Android SDK and set System PATH
C:\Android-SDK\cmdline-tools\latest\bin
C:\Android-SDK\platform-tools

In pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core:
  firebase_auth: 
  cloud_firestore:

flutter pub get

npm install -g firebase-tools

Login firebase in website with mail id and create a project and download the json file and move it to android/app

In cmd
firebase login

dart pub global activate flutterfire_cli

Add C:\Users\harir\AppData\Local\Pub\Cache\bin in System PATH

flutterfire configure   // this will create firebase_options.dart file

choose the project and platform

add this in main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}