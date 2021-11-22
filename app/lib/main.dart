import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

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
  late final Future<Interpreter> interpreter;
  late final TextEditingController controller;
  late String result;
  late String punctuation;
  late Map tokenizer;
  late Map encoder;
  late Map responses;

  late final ScrollController _controller;


  Future<String> get _encoder async {
    return await rootBundle.loadString('assets/encoder.json');
  }

  Future<String> get _word_dict async {
    return await rootBundle.loadString('assets/word_dict.json');
  }

  Future<String> get _respondes async {
    return await rootBundle.loadString('assets/responses.json');
  }


  getData() async {
    final responses_ = await _respondes;
    final encoder_ = await _encoder;
    final tokenizer_ = await _word_dict;

    responses = jsonDecode(responses_);
    encoder = jsonDecode(encoder_);
    tokenizer = jsonDecode(tokenizer_);
    interpreter = Interpreter.fromAsset("model.tflite");

    Map encoder__ = {};

    for (var i in encoder.keys) {
      encoder__[encoder[i]] = i;
    }
    encoder = encoder__;
    return "";
  }

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    result = "";
    _controller = ScrollController();
    punctuation = r"""!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~""";
    getData();
  }

  argmax(List a) {
    return a.indexOf(a.fold(0, (c, d) => d > c ? d : c));
  }

  texts_to_sequences(List a) {
    List<Object> result = [];
    for (String i in a) {
      for (String ii in i.split(" ")) {
        if (tokenizer.containsKey(ii)) {
          result.add(double.parse(tokenizer[ii].toString()));
        }
      }
    }
    return result;
  }

  pad_sequences(List a, int shape) {
    if (shape != a.length) {
      while (!(a.length == shape)) {
        a.insert(0, 0.0);
      }
    }
    return a;
  }

  Future<dynamic> get_result(String input, Interpreter data) async {
    String input_ = "";
    List<Object> newInput = [];
    Tensor inputDetails = data.getInputTensor(0);
    Tensor outputDetails = data.getOutputTensor(0);
    List text = [];

    input.split("").forEach((char) {
      if (!punctuation.contains(char)) {
        input_ = input_ + char;
      }
    });
    input = input_;
    text.add(input);
    newInput = texts_to_sequences(text);

    newInput = [pad_sequences(newInput, inputDetails.shape[1])];
    Map<int, List> output = {
      0: [
        [for (var i = 1; i <= outputDetails.shape[1]; i++) 0.0]
      ]
    };
    data.runForMultipleInputs([newInput], output);

    late int newOutput;
    newOutput = argmax(output[0]![0]);
    var tag = encoder[newOutput];

    if (responses[tag] != null) {
      result = (responses[tag].toList()..shuffle()).first.toString().format({
        "time": DateFormat("kk:mm").format(DateTime.now()),
      });
    } else {
      result = "";
    }
    return result;
  }

  String answer = "";

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
            body: Column(
              children: [
                Row(
                  children: [
                    Flexible(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: "Ask me something"),
                        textInputAction: TextInputAction.go,
                        onSubmitted: (value) async {
                          if (controller.text.isNotEmpty) {
                            var input = controller.text;
                            get_result(input, await interpreter).then((value) {
                              answer = value;
                              controller.text = "";
                              setState(() {});
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                Text(answer),
              ],
            ),
          );
        }));
  }
}
