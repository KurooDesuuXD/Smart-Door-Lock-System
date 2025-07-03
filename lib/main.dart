import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:local_auth/local_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SecureEntryApp());
}

class SecureEntryApp extends StatelessWidget {
  const SecureEntryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureEntry',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const PinUnlockPage(),
    );
  }
}

class PinUnlockPage extends StatefulWidget {
  const PinUnlockPage({super.key});

  @override
  State<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<PinUnlockPage> {
  final TextEditingController _pinController = TextEditingController();
  String _correctPin = "";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPinFromFirebase();
  }

  Future<void> _validatePin(String enteredPin) async {
  final auth = LocalAuthentication();
  final isAvailable = await auth.canCheckBiometrics;
  final isSupported = await auth.isDeviceSupported();

  if (isAvailable && isSupported) {
    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Use biometrics to unlock the door',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow pattern or fallback
          stickyAuth: true,
        ),
      );

      if (!didAuthenticate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Biometric authentication failed')),
        );
        return;
      }
    } catch (e) {
      print('⚠️ Biometric error: $e');
      return;
    }
  }

  final pinSnapshot = await FirebaseDatabase.instance
      .ref("settings/pin_code")
      .get();

  final storedPin = pinSnapshot.value.toString();

  if (enteredPin == storedPin) {
    await FirebaseDatabase.instance.ref("door").update({
      'status': 'unlocked',
      'method': 'PIN + Biometric',
      'timestamp': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Door unlocked')),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DoorControlPage()),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ Incorrect PIN')),
    );
  }
}


  Future<void> _fetchPinFromFirebase() async {
  final ref = FirebaseDatabase.instance.ref("settings/pin_code");
  final snapshot = await ref.get();

  if (snapshot.exists) {
    setState(() {
      _correctPin = snapshot.value.toString();
      _loading = false;
    });
  } else {
    setState(() {
      _correctPin = "0000"; // default fallback
      _loading = false;
    });
  }
}

@override
Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Enter PIN to Unlock")),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Enter 4-digit PIN", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            PinCodeTextField(
              appContext: context,
              length: 4,
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              onCompleted: _validatePin,
              onChanged: (value) {},
            ),
          ],
        ),
      ),
    );
  }
}

class DoorControlPage extends StatefulWidget {
  const DoorControlPage({super.key});

  @override
  State<DoorControlPage> createState() => _DoorControlPageState();
}

class _DoorControlPageState extends State<DoorControlPage> {
  final DatabaseReference _doorStatusRef = FirebaseDatabase.instance.ref('door/status');
  final DatabaseReference _doorMethodRef = FirebaseDatabase.instance.ref('door/method');

  bool _isUnlocked = false;
  String _unlockMethod = "unknown";
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _doorStatusRef.onValue.listen((event) {
      final status = event.snapshot.value.toString();
      setState(() {
        _isUnlocked = status == 'unlocked';
        _loading = false;
      });
    });

    _doorMethodRef.onValue.listen((event) {
      final method = event.snapshot.value.toString();
      setState(() {
        _unlockMethod = method;
      });
    });
  }

  void _toggleDoor() async {
    final newStatus = _isUnlocked ? 'locked' : 'unlocked';
    final method = "app";

    await _doorStatusRef.set(newStatus);
    await FirebaseDatabase.instance.ref("door/method").set(method);

    final logRef = FirebaseDatabase.instance.ref("logs").push();
    final timestamp = DateTime.now().toString();

    await logRef.set({
      "status": newStatus,
      "method": method,
      "timestamp": timestamp,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Door Lock'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isUnlocked ? Icons.lock_open : Icons.lock,
                    size: 100,
                    color: _isUnlocked ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isUnlocked ? 'Door is UNLOCKED' : 'Door is LOCKED',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Method: $_unlockMethod',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _toggleDoor,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: _isUnlocked ? Colors.red : Colors.green,
                    ),
                    child: Text(
                      _isUnlocked ? 'LOCK DOOR' : 'UNLOCK DOOR',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LogsPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: Colors.blueGrey,
                    ),
                    child: const Text("View Logs", style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _newPinController = TextEditingController();
  final DatabaseReference _pinRef = FirebaseDatabase.instance.ref("settings/pin_code");

  void _updatePin() async {
    final newPin = _newPinController.text.trim();
    if (newPin.length == 4 && RegExp(r'^\d{4}$').hasMatch(newPin)) {
      await _pinRef.set(newPin);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ PIN updated successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Enter a valid 4-digit PIN")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Update PIN")),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("New 4-digit PIN", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: _newPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updatePin,
              child: const Text("Update PIN"),
            ),
          ],
        ),
      ),
    );
  }
}

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final DatabaseReference _logsRef = FirebaseDatabase.instance.ref("logs");
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref("users");
  List<Map<String, dynamic>> _logList = [];
  bool _loading = true;
  bool _isAdmin = false;
  String _uid = "";

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _loadLogs();
  }

  Future<void> _fetchUserRole() async {
    // 🔒 Replace this with real UID fetching logic if using FirebaseAuth
    // Example placeholder UID:
    _uid = "b9117e05"; // Replace with actual UID

    final snapshot = await _usersRef.child("$_uid/role").get();
    if (snapshot.exists && snapshot.value == "admin") {
      setState(() {
        _isAdmin = true;
      });
    }
  }

  void _loadLogs() {
    _logsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      final List<Map<String, dynamic>> logs = [];

      if (data != null) {
        data.forEach((key, value) {
          final log = Map<String, dynamic>.from(value);
          logs.add(log);
        });
        logs.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      }

      setState(() {
        _logList = logs;
        _loading = false;
      });
    });
  }

  void _clearLogs() async {
    await _logsRef.remove();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🧼 Logs cleared successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Access Logs"),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _clearLogs,
              tooltip: "Clear All Logs",
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logList.isEmpty
              ? const Center(child: Text("No logs yet"))
              : ListView.builder(
                  itemCount: _logList.length,
                  itemBuilder: (context, index) {
                    final log = _logList[index];
                    return ListTile(
                      leading: Icon(
                        log["status"] == "unlocked" ? Icons.lock_open : Icons.lock,
                        color: log["status"] == "unlocked" ? Colors.green : Colors.red,
                      ),
                      title: Text("Status: ${log['status']}"),
                      subtitle: Text("Method: ${log['method']}\n${log['timestamp']}"),
                      isThreeLine: true,
                    );
                  },
                ),
    );
  }
}

