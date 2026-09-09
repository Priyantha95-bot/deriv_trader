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
      title: 'Deriv Pro Advanced Trader & Bot',
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
  late WebSocketChannel _channel;

  bool _isAutoMode = false;
  bool _isBotRunning = false;
  String _selectedMarket = 'R_75'; 
  
  String _selectedContract = 'DIGITMATCH';
  double _baseStake = 1.0;
  double _currentStake = 1.0;
  int _duration = 1;
  int _barrier = 5;
  double _takeProfit = 50.0;
  double _stopLoss = 20.0;
  double _martingaleMultiplier = 2.0; 
  double _totalProfitLoss = 0.0;

  String _price = 'Connecting...';
  String _statusMessage = 'Please enter your API Token in Settings (⚙️)';
  bool _isAuthorized = false;
  
  final Map<int, int> _digitCounts = {0:0, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0};
  int _totalTicks = 0;

  final TextEditingController _tokenController = TextEditingController();

  final Map<String, String> _markets = {
    'Volatility 75 Index': 'R_75',
    'Volatility 10 Index': 'R_10',
    'Volatility 25 Index': 'R_25',
    'Volatility 50 Index': 'R_50',
    'Volatility 100 Index': 'R_100',
    'Boom 1000': 'BOOM1000',
    'Crash 1000': 'CRASH1000',
    'Forex - EUR/USD': 'frxEURUSD',
    'Forex - GBP/USD': 'frxGBPUSD',
  };

  final Map<String, String> _contracts = {
    'Rise / Fall': 'CALL',
    'Even / Odd (Even)': 'DIGITEVEN',
    'Over / Under': 'DIGITOVER',
    'Matches / Differs': 'DIGITMATCH',
  };

  @override
  void initState() {
    super.initState();
    _currentStake = _baseStake;
    _initWebSocket();
  }

  void _initWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://ws.derivws.com/websockets/v3?app_id=1089'),
    );

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
            _statusMessage = 'Authorized: ${data['authorize']['email']} (Balance: ${data['authorize']['balance']} USD)';
            _isAuthorized = true;
          });
        }
      }

      if (data['msg_type'] == 'tick') {
        if (data['tick'] != null && data['tick']['symbol'] == _selectedMarket) {
          final quote = data['tick']['quote'].toString();
          setState(() {
            _price = quote;
          });

          if (quote.contains('.')) {
            String lastChar = quote.split('.').last;
            if (lastChar.isNotEmpty) {
              int lastDigit = int.parse(lastChar[lastChar.length - 1]);
              setState(() {
                _digitCounts[lastDigit] = (_digitCounts[lastDigit] ?? 0) + 1;
                _totalTicks++;
              });

              if (_isAutoMode && _isBotRunning && _isAuthorized) {
                _evaluateBotStrategy(lastDigit);
              }
            }
          }
        }
      }

      if (data['msg_type'] == 'buy') {
        if (data['error'] != null) {
          setState(() {
            _statusMessage = 'Bot/Trade Error: ${data['error']['message']}';
          });
        } else {
          setState(() {
            _statusMessage = 'Trade Placed! ID: ${data['buy']['contract_id']} (Stake: \$$_currentStake)';
          });
        }
      }
    });

    _subscribeMarket(_selectedMarket);
  }

  void _subscribeMarket(String symbol) {
    setState(() {
      _digitCounts.updateAll((key, value) => 0);
      _totalTicks = 0;
      _price = 'Loading...';
    });
    try {
      _channel.sink.add(jsonEncode({"forget_all": "ticks"}));
      _channel.sink.add(jsonEncode({"ticks": symbol}));
    } catch (e) {
      // Handle connection sync if needed
    }
  }

  void _authorizeUser(String token) {
    if (token.isEmpty) return;
    setState(() {
      _statusMessage = 'Authorizing with Deriv API...';
    });
    _channel.sink.add(jsonEncode({"authorize": token}));
  }

  void _evaluateBotStrategy(int lastDigit) {
    if (_totalTicks % 5 == 0) { 
      _executeAutomatedTrade();
    }
  }

  void _executeManualTrade() {
    if (!_isAuthorized) {
      setState(() => _statusMessage = 'Error: Please add API Token in settings first!');
      return;
    }
    _sendBuyRequest(_baseStake);
  }

  void _executeAutomatedTrade() {
    if (_totalProfitLoss >= _takeProfit || _totalProfitLoss <= -_stopLoss) {
      setState(() {
        _isBotRunning = false;
        _statusMessage = 'Bot Stopped: Profit/Loss limit reached! P/L: \$$_totalProfitLoss';
      });
      return;
    }
    _sendBuyRequest(_currentStake);
  }

  void _sendBuyRequest(double stakeAmount) {
    Map<String, dynamic> parameters = {
      "amount": stakeAmount,
      "basis": "stake",
      "currency": "USD",
      "symbol": _selectedMarket,
      "duration": _duration,
      "duration_unit": "t",
      "contract_type": _selectedContract,
    };

    if (_selectedContract == 'DIGITOVER' || _selectedContract == 'DIGITUNDER' || _selectedContract == 'DIGITMATCH') {
      parameters["barrier"] = _barrier.toString();
    }

    final tradeRequest = {
      "buy": 1,
      "price": stakeAmount,
      "parameters": parameters,
    };

    _channel.sink.add(jsonEncode(tradeRequest));
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161822),
        title: const Text('Deriv API Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your Deriv API Token:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(hintText: 'API Token', border: OutlineInputBorder()),
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
        title: const Text('DERIV PRO DYNAMIC TRADER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: const Color(0xFF1F222E),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.amber),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1F222E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isAutoMode ? 'Mode: DYNAMIC BOT' : 'Mode: MANUAL TRADING',
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
                        _isBotRunning = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F222E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Trading Market / Asset:', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: _selectedMarket,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1F222E),
                    underline: const SizedBox(),
                    items: _markets.keys.map((String name) {
                      return DropdownMenuItem<String>(
                        value: _markets[name],
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedMarket = newValue;
                        });
                        _subscribeMarket(newValue);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161822),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Live LDP Price:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(_price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1F222E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last Digit Stats (Total Ticks: $_totalTicks)', style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(10, (index) {
                      int count = _digitCounts[index] ?? 0;
                      double percentage = _totalTicks > 0 ? (count / _totalTicks) * 100 : 0.0;
                      return Column(
                        children: [
                          Text('$index', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: percentage > 11 ? Colors.greenAccent : Colors.grey)),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isAuthorized ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(color: _isAuthorized ? Colors.greenAccent : Colors.amber, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            if (!_isAutoMode) ...[
              const Text('Contract Type:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFF1F222E), borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<String>(
                  value: _selectedContract,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1F222E),
                  underline: const SizedBox(),
                  items: _contracts.keys.map((String name) {
                    return DropdownMenuItem<String>(
                      value: _contracts[name],
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (String? val) => setState(() => _selectedContract = val!),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _baseStake.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stake (\$)', border: OutlineInputBorder()),
                      onChanged: (val) => _baseStake = double.tryParse(val) ?? 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: _duration.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ticks Duration', border: OutlineInputBorder()),
                      onChanged: (val) => _duration = int.tryParse(val) ?? 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _barrier.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Barrier / Prediction Digit (0-9)', border: OutlineInputBorder()),
                onChanged: (val) => _barrier = int.tryParse(val) ?? 5,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _executeManualTrade,
                  child: const Text('EXECUTE MANUAL TRADE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ] else ...[
              const Text('Bot Strategy & Risk Management Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purpleAccent)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFF1F222E), borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<String>(
                  value: _selectedContract,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1F222E),
                  underline: const SizedBox(),
                  items: _contracts.keys.map((String name) {
                    return DropdownMenuItem<String>(
                      value: _contracts[name],
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (String? val) => setState(() => _selectedContract = val!),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _baseStake.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Base Stake (\$)', border: OutlineInputBorder()),
                      onChanged: (val) => _baseStake = double.tryParse(val) ?? 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: _barrier.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Target Barrier', border: OutlineInputBorder()),
                      onChanged: (val) => _barrier = int.tryParse(val) ?? 5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _takeProfit.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Take Profit (\$)', border: OutlineInputBorder()),
                      onChanged: (val) => _takeProfit = double.tryParse(val) ?? 50.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: _stopLoss.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stop Loss (\$)', border: OutlineInputBorder()),
                      onChanged: (val) => _stopLoss = double.tryParse(val) ?? 20.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _martingaleMultiplier.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Martingale Multiplier', border: OutlineInputBorder()),
                onChanged: (val) => _martingaleMultiplier = double.tryParse(val) ?? 2.0,
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBotRunning ? Colors.red : Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    setState(() {
                      _isBotRunning = !_isBotRunning;
                      if (_isBotRunning) {
                        _currentStake = _baseStake;
                        _totalProfitLoss = 0.0;
                        _statusMessage = 'Dynamic Bot Started Successfully...';
                      } else {
                        _statusMessage = 'Dynamic Bot Stopped by User.';
                      }
                    });
                  },
                  child: Text(
                    _isBotRunning ? 'STOP AUTOMATED BOT' : 'START AUTOMATED BOT',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
