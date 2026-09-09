import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const DerivProTraderApp());
}

class DerivProTraderApp extends StatelessWidget {
  const DerivProTraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deriv Pro Trader',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1015),
        primaryColor: Colors.blueAccent,
      ),
      home: const ProTraderDashboard(),
    );
  }
}

class ProTraderDashboard extends StatefulWidget {
  const ProTraderDashboard({super.key});

  @override
  State<ProTraderDashboard> createState() => _ProTraderDashboardState();
}

class _ProTraderDashboardState extends State<ProTraderDashboard> {
  // Deriv WebSocket Connection
  final _channel = WebSocketChannel.connect(
    Uri.parse('wss://ws.derivws.com/websockets/v3?app_id=1089'),
  );

  bool _isAutoMode = false;
  String _selectedSymbol = 'R_75';
  String _selectedContract = 'CALL';
  double _stake = 10.0;
  int _duration = 5;
  double _takeProfit = 50.0;
  double _stopLoss = 20.0;
  
  String _price = 'Connecting...';
  String _statusMessage = 'Please enter API Token in Settings';
  bool _isAuthorized = false;
  
  final TextEditingController _tokenController = TextEditingController();

  final Map<String, String> _symbols = {
    'Volatility 75 Index': 'R_75',
    'Volatility 10 Index': 'R_10',
    'Volatility 50 Index': 'R_50',
    'Volatility 100 Index': 'R_100',
  };

  @override
  void initState() {
    super.initState();
    _channel.stream.listen((message) {
      final data = jsonDecode(message);
      
      if (data['msg_type'] == 'authorize') {
        if (data['error'] != null) {
          setState(() {
            _statusMessage = 'Auth Error: ${data['error']['message']}';
            _isAuthorized = false;
          });
        } else {
          setState(() {
            _statusMessage = 'Connected: ${data['authorize']['email']}';
            _isAuthorized = true;
          });
        }
      }

      if (data['msg_type'] == 'tick') {
        if (data['tick'] != null && data['tick']['symbol'] == _selectedSymbol) {
          setState(() {
            _price = data['tick']['quote'].toString();
          });
        }
      }

      if (data['msg_type'] == 'buy') {
        if (data['error'] != null) {
          setState(() {
            _statusMessage = 'Trade Failed: ${data['error']['message']}';
          });
        } else {
          setState(() {
            _statusMessage = 'Order Successful! ID: ${data['buy']['contract_id']}';
          });
        }
      }
    });

    // Subscribe to default market
    _subscribeMarket(_selectedSymbol);
  }

  void _subscribeMarket(String symbol) {
    _channel.sink.add(jsonEncode({"forget_all": "ticks"}));
    _channel.sink.add(jsonEncode({"ticks": symbol}));
  }

  void _authorizeUser(String token) {
    if (token.isEmpty) return;
    setState(() {
      _statusMessage = 'Authorizing...';
    });
    _channel.sink.add(jsonEncode({"authorize": token}));
  }

  void _executeTrade() {
    if (!_isAuthorized) {
      setState(() {
        _statusMessage = 'Error: Authorize with API Token first!';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Executing $_selectedContract order...';
    });

    final tradeRequest = {
      "buy": 1,
      "price": _stake,
      "parameters": {
        "amount": _stake,
        "basis": "stake",
        "currency": "USD",
        "symbol": _selectedSymbol,
        "duration": _duration,
        "duration_unit": "t",
        "contract_type": _selectedContract
      }
    };
    _channel.sink.add(jsonEncode(tradeRequest));
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161822),
        title: const Text('Deriv Account Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your Deriv API Token to enable live trading:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                hintText: 'API Token',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _authorizeUser(_tokenController.text.trim());
            },
            child: const Text('Save & Authorize', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DERIV PRO TRADER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1F222E),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.amber),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Switcher (Manual / Automated Bot)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F222E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isAutoMode ? 'Mode: AUTOMATED BOT' : 'Mode: MANUAL TRADING',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isAutoMode ? Colors.purpleAccent : Colors.greenAccent,
                    ),
                  ),
                  Switch(
                    value: _isAutoMode,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) {
                      setState(() {
                        _isAutoMode = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // Market Selector Dropdown
            const Text('Select Market:', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F222E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedSymbol,
                isExpanded: true,
                dropdownColor: const Color(0xFF1F222E),
                underline: const SizedBox(),
                items: _symbols.keys.map((String name) {
                  return DropdownMenuItem<String>(
                    value: _symbols[name],
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSymbol = newValue;
                      _price = 'Loading...';
                    });
                    _subscribeMarket(newValue);
                  }
                },
              ),
            ),
            const SizedBox(height: 15),

            // Live Price Display Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161822),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Live Market Price:', style: TextStyle(fontSize: 16)),
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
            ),
            const SizedBox(height: 15),

            // Status Message Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isAuthorized ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: _isAuthorized ? Colors.greenAccent : Colors.amber,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            if (!_isAutoMode) ...[
              // MANUAL TRADING CONTROLS
              const Text('Contract Type:', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedContract == 'CALL' ? Colors.green : Colors.grey[800],
                      ),
                      onPressed: () => setState(() => _selectedContract = 'CALL'),
                      child: const Text('HIGHER / CALL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedContract == 'PUT' ? Colors.red : Colors.grey[800],
                      ),
                      onPressed: () => setState(() => _selectedContract = 'PUT'),
                      child: const Text('LOWER / PUT'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stake ($)', border: OutlineInputBorder()),
                      controller: TextEditingController(text: _stake.toString()),
                      onChanged: (val) => _stake = double.tryParse(val) ?? 10.0,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (Ticks)', border: OutlineInputBorder()),
                      controller: TextEditingController(text: _duration.toString()),
                      onChanged: (val) => _duration = int.tryParse(val) ?? 5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _executeTrade,
                  child: Text('PLACE ${_selectedContract} ORDER', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ] else ...[
              // AUTOMATED BOT SETTINGS
              const Text('Automated Bot Parameters:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purpleAccent)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Take Profit ($)', border: OutlineInputBorder()),
                      controller: TextEditingController(text: _takeProfit.toString()),
                      onChanged: (val) => _takeProfit = double.tryParse(val) ?? 50.0,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stop Loss ($)', border: OutlineInputBorder()),
                      controller: TextEditingController(text: _stopLoss.toString()),
                      onChanged: (val) => _stopLoss = double.tryParse(val) ?? 20.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    setState(() {
                      _statusMessage = 'Bot Engine Started (Demo/Live mode active)';
                    });
                  },
                  child: const Text('START TRADING BOT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
