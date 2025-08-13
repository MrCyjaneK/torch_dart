import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:torch_dart/abstract_tor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Tor> torList = [];

  @override
  void initState() {
    super.initState();
    Tor.getTorList().then((list) {
      setState(() {
        torList = list;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Tor'),
        ),
        body: ListView.builder(
          itemCount: torList.length,
          itemBuilder: (context, index) {
            return Card(
              child: ListTile(
                title: Text(torList[index].toString()),
                subtitle: Text(torList[index].toJson()),
                onTap: () {
                  print("starting tor");
                  try {
                    runTor(torList[index]);
                  } catch (e) {
                    print("error starting tor: $e");
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

void runTor(Tor tor) {
  Isolate.run(() {
    tor.start([]);
  });
}