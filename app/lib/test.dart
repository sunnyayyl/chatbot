
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyApp createState() => _MyApp();
}

extension formatting on String {
  String format(Map<String, String> a) {
    return replaceAllMapped(RegExp(r"{(.*?)}"), (match) {
      if (a[match[1]] == null) {
        throw "error";
      }
      return a[match[1]] ?? "";
    });
  }
}

class _MyApp extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Builder(builder: (context) {
          return Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(title: const Text("Chatbot")),
            body: Container(),
          );
        }));
  }
}
