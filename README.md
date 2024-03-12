# Flutter QJS plugin

Flutter bindings with dart:ffi for QuickJS : A small Javascript engine supports **ES2020**.


## Examples

Here is a small flutter app showing how to evaluate javascript code inside a flutter app



```dart
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _jsResult = '';
  JavascriptRuntime flutterJs;
  @override
  void initState() {
    super.initState();
    
    flutterJs = getJavascriptRuntime();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FlutterJS Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('JS Evaluate Result: $_jsResult\n'),
              SizedBox(height: 20,),
              Padding(padding: EdgeInsets.all(10), child: Text('Click on the big JS Yellow Button to evaluate the expression bellow using the flutter_qjs plugin'),),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Math.trunc(Math.random() * 100).toString();", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),),
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.transparent, 
          child: Image.asset('assets/js.ico'),
          onPressed: () async {
            try {
              JsEvalResult jsResult = flutterJs.evaluate(
                  "Math.trunc(Math.random() * 100).toString();");
              setState(() {
                _jsResult = jsResult.stringResult;
              });
            } on PlatformException catch (e) {
              print('ERRO: ${e.details}');
            }
          },
        ),
      ),
    );
  }
}

```


**How to call dart from Javascript**

You can add a channel on `JavascriptRuntime` objects to receive calls from the Javascript engine:

In the dart side:

```dart
javascriptRuntime.onMessage('someChannelName', (dynamic args) {
     print(args);
});
```


Now, if your javascript code calls `sendMessage('someChannelName', JSON.stringify([1,2,3]);` the above dart function provided as the second argument will be called
with a List containing 1, 2, 3 as it elements.

## Reference
- [ekibun/flutter_qjs](https://github.com/ekibun/flutter_qjs)
- [abner/flutter_js](https://github.com/abner/flutter_js)
