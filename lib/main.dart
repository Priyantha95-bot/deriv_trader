import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deriv Trader',
      theme: ThemeData.dark(),
      home: const TraderDashboard(),
    );
  }
}

class TraderDashboard extends StatefulWidget {
  const TraderDashboard({super.key});

  @override
  State<TraderDashboard> createState() => _TraderDashboardState();
}

class _TraderDashboardState extends State<TraderDashboard> {
  // Deriv Public WebSocket URL
  final _channel = WebSocketChannel.connect(
    Uri.parse('wss://ws.derivws.com/websockets/v3?app_id=1089'),
  );

  String _price = 'Connecting...';
  String _message = '';

  @override
  void initState() {
    super.initState();
    // Subscribe to Volatility 75 Index (R_75)
    _channel.sink.add(jsonEncode({"ticks": "R_75"}));
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  void _placeBuyOrder() {
    setState(() {
      _message = 'Buy order placed successfully!';
    });
    // Here you can add real trade execution request if authorized
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deriv Trader Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market: Volatility 75 Index',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            StreamBuilder(
              stream: _channel.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  var data = jsonDecode(snapshot.data.toString());
                  if (data['tick'] != null) {
                    _price = data['tick']['quote'].toString();
                  }
                }
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('LDP Price:', style: TextStyle(fontSize: 16)),
                      Text(
                        _price,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                onPressed: _placeBuyOrder,
                child: const Text(
                  'Place Buy Order',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _message,
                style: const TextStyle(color: Colors.amber, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
