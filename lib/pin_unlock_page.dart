import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class PinUnlockPage extends StatefulWidget {
  const PinUnlockPage({super.key});

  @override
  State<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<PinUnlockPage> {
  final TextEditingController _pinController = TextEditingController();
  final String _correctPin = "1234"; // 🔒 Change this to your actual pin

  void _validatePin(String pin) {
    if (pin == _correctPin) {
      FirebaseDatabase.instance.ref("door/status").set("unlocked");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Door Unlocked")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Incorrect PIN")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
