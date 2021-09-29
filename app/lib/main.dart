import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

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

class Message {
  String message;
  String sender;

  Message({required this.message, required this.sender});
}

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyApp createState() => _MyApp();
}

class _MyApp extends State<MyApp> {
  late List<Widget> _widgetOptions;
  //late final Interpreter interpreter_;
  late final Future<Interpreter> interpreter;
  late final TextEditingController controller;
  late String result;
  late String punctuation;
  late Map tokenizer;
  late Map encoder;
  late Map responses;
  late Map jobs;
  late List messages;
  late final ScrollController _controller;
  late SharedPreferences prefs;
  late var weather;
  late var wikipedia;
  getData() async {
    tokenizer = jsonDecode(await DefaultAssetBundle.of(context)
        .loadString("assets/word_dict.json"));
    Map encoder_ = {};
    encoder = jsonDecode(
        await DefaultAssetBundle.of(context).loadString("assets/encoder.json"));
    for (var i in encoder.keys) {
      encoder_[encoder[i]] = i;
    }
    encoder = encoder_;
    responses = jsonDecode(await DefaultAssetBundle.of(context)
        .loadString("assets/responses.json"));
    jobs = jsonDecode(
        await DefaultAssetBundle.of(context).loadString("assets/jobs.json"));
    weather=await getWeather();
  }

  @override
  void initState() {
    super.initState();
    interpreter = Interpreter.fromAsset('model.tflite');
    controller = TextEditingController();
    result = "";
    _controller=ScrollController();
    punctuation = r"""!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~""";
    messages = [];
    wikipedia=[];
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
  int _selected = 0;
  void _onItemTapped(int index) {
    setState(() {
      _selected = index;
    });
  }
  void log(String str)async{
    prefs = await SharedPreferences.getInstance();
    String? log=prefs.getString("log");
    if (log==null){
      log=str;
    }else{
      log=log+"\n"+str;
    }
    await prefs.setString("log", log);
  }
  getWeather()async{
    http.Response data_=await http.get(Uri.parse("https://api.openweathermap.org/data/2.5/weather?id=1819729&appid=a03cf4b424ffa1976d1fc494ec38e0fa"));
    Map data=json.decode(data_.body);
    return [data["weather"][0]["main"],data["main"]["temp"]];
  }
  getWikipediaResult(String a) async{
    http.Response data_=await http.get(Uri.parse("https://en.wikipedia.org/w/api.php?action=opensearch&search=${a}&limit=1&namespace=0&format=json"));
    List data=json.decode(data_.body);
    return [data[1][0],data[3][0]];
  }
  Future<dynamic> get_result(String input, AsyncSnapshot<dynamic> snapshot) async {

    Interpreter data = (snapshot.data as Interpreter);
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
    if (jobs[tag] != null) {
      if (jobs[tag].contains("weather")){
        weather=await getWeather();
      }else if(jobs[tag].contains("wikipedia")){
        wikipedia=await getWikipediaResult([for (var i in input.split(" ")) ((["what","is","what's","do","mean","a","whats"]+punctuation.split("")).contains(i))?"":i ].toString());
      }
    }
    if (responses[tag] != null) {
      result = (responses[tag].toList()
        ..shuffle())
          .first
          .toString()
          .format({
            "time": DateFormat("kk:mm").format(DateTime.now()),
            "main": weather[0],
            "temperature": (weather[1]- 273.15).toStringAsFixed(1),
            "wikipedia_title": wikipedia[0]??"unknown",
            "wikipedia_link":wikipedia[1]??"unknown"
          });
    } else {
      result = "";
    }

    log("User input: " + input);
    log("Input: " + newInput.toString());
    log("Output: " + output.toString());
    log("Tag: " + tag);
    log("Jobs: " + (jobs[tag]??[null]).toString());
    if (wikipedia.isNotEmpty){
      log("Searching: "+wikipedia[0]);
    }
    log("Bot output: "+result);
    log("\n");
    return result;
  }


  @override
  Widget build(BuildContext context) {

    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Builder(
          builder: (context) {
            _widgetOptions=<Widget>[
              FutureBuilder(
                builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                  sent(a){

                    if (controller.text.isNotEmpty){
                      var input=controller.text;
                      controller.text="";
                      messages.add(Message(message: input, sender: "you"));
                      get_result(input, snapshot).then((value) {
                        messages.add(Message(message: value, sender: "bot"));

                        setState(() {
                        });
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _controller.animateTo(
                            _controller.position.maxScrollExtent,
                            curve: Curves.easeOut,
                            duration: const Duration(milliseconds: 500),
                          );
                        });
                      });


                    }
                  }
                  if (snapshot.hasData) {
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _controller,
                            itemBuilder: (context, index) {
                              return Container(
                                padding: const EdgeInsets.only(left: 16,right: 16,top: 10,bottom: 10),
                                child: Align(alignment: (messages[index].sender == "bot"?Alignment.topLeft:Alignment.topRight),child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: (messages[index].sender  == "bot"?Colors.grey.shade200:Colors.blue[300]),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Text(messages[index].message, style: const TextStyle(fontSize: 15),),
                                ),),
                              );
                            },
                            itemCount: messages.length,
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(top: 10, bottom: 10),),
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: const EdgeInsets.only(
                                left: 10, bottom: 10, top: 10),
                            height: 60,
                            child: Row(
                              children: [
                                Flexible(
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: "Ask me something"),
                                    textInputAction: TextInputAction.go,
                                    onSubmitted: sent,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send),
                                  onPressed:()=>sent(""),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    );
                  } else if (snapshot.hasError) {
                    log(snapshot.error.toString());
                    return const Center(
                      child: Text("Error"),
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
                future: interpreter,
              ),
              FutureBuilder(builder: (context, AsyncSnapshot<dynamic> snapshot) {
                if (snapshot.hasData){
                  return SingleChildScrollView(child: Text(snapshot.data.getString("log")??"No log found"));
                }else if(snapshot.hasError){
                  log(snapshot.error.toString());
                  return const Center(child: Text("Error"));
                }else{
                  return const Center(child: CircularProgressIndicator());
                }
              },future: SharedPreferences.getInstance(),),
              ListView(children: [
                ListTile(title: const Text("Open source licence"),onTap: () => showLicensePage(context: context),)
              ],),
            ];
            return Scaffold(
              resizeToAvoidBottomInset: true,
              bottomNavigationBar: BottomNavigationBar(
                items: const <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat),
                    label: "Chat",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.assignment),
                    label: 'Log',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: 'Setting',
                  ),
                ],
                currentIndex: _selected,
                selectedItemColor: Colors.amber[800],
                onTap: _onItemTapped,
              ),
              appBar: AppBar(title: const Text("Chatbot")),
              body: _widgetOptions.elementAt(_selected),
            );
          }
        ));
  }
}
