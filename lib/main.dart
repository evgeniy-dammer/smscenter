import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:connectivity/connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:smscenter/messagemodel.dart';

void main() async {
  runApp(SMSCenterApp());
}

class SMSCenterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SMS Center',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage()
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  SharedPreferences prefs;

  ValueNotifier<bool> _notifier = ValueNotifier(false);

  List<Message> allMessages = List<Message>();

  WebSocketChannel _channelRecieve;
  WebSocketChannel _channelSend;

  bool isSwitched = false;

  @override
  void initState(){
    _doThis();
    super.initState();
  }

  @override
  void dispose(){
    _disconnectSockets();
    super.dispose();
  }

  _doThis() async {
    prefs = await _prefs;

    setState(() {
      isSwitched = prefs.getBool("state") != null ? prefs.getBool("state") : false;
    });

    if(isSwitched){
      _connectSockets();
    }
  }

  _disconnectSockets() async {
    _channelRecieve.sink.close();
    _channelSend.sink.close();
  }

  _connectSockets() async {
    var connectivityResult = await (Connectivity().checkConnectivity());

    if (connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi){
      _channelRecieve = WebSocketChannel.connect(
        Uri.parse('ws://192.168.1.34:8181/api/mobile/getsms/'), //10.0.2.2
      );
      _channelSend = WebSocketChannel.connect(
        Uri.parse('ws://192.168.1.34:8181/api/mobile/smssent/'), //10.0.2.2
      );
    } else {
      isSwitched = false;
      prefs.setBool("state", false);
    }
  }

  _makeSent(String id) async {
    _channelSend.sink.add(id);
  }

  _sendSms(Message message) async {
    Telephony telephony = Telephony.instance;

    final SmsSendStatusListener listener = (SendStatus status) {
      if (status == SendStatus.SENT) {
        print("SENT");
        _makeSent(message.id);
      }
    };

    await telephony.sendSms(
      to: message.phone,
      message: message.message,
      statusListener: listener
    );

    await _addMessage(message);
  }

  _addMessage(Message message) async {
    _notifier.value = !_notifier.value;
    allMessages.add(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("SMS Center"),
        actions: <Widget>[
          Switch(
            value: isSwitched,
            activeColor: Colors.green,
            activeTrackColor: Colors.green,
            inactiveTrackColor: Colors.red,
            inactiveThumbColor: Colors.red,
            onChanged: (value){
              setState(() {
                if(value) {
                  _connectSockets();
                } else {
                  _disconnectSockets();
                }

                isSwitched = value;
                prefs.setBool("state", value);
              });
            }
          )
        ]
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(10.0,0,10.0,0),
        child: ListView(
          children: <Widget>[
            !isSwitched ? Text("") : StreamBuilder(
              stream: _channelRecieve.stream,
              builder: (context, snapshot) {
                print(snapshot.data);

                if (snapshot.hasData) {
                  Message message = Message.fromMap(json.decode(snapshot.data));
                  _sendSms(message);

                  return Text("");
                }
                return Text("");
              }
            ),
            ValueListenableBuilder(
              valueListenable: _notifier,
              builder: (BuildContext context, bool quoteReady, Widget child) {
                return Container(
                  height: 500.0,
                  child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    itemCount: allMessages.length,
                    itemBuilder: (BuildContext context, int index) {
                      Message m = allMessages[index];
                      return Text(m.date + " - " + m.phone);
                    }
                  )
                );
              }
            )
          ]
        )
      )
    );
  }
}
