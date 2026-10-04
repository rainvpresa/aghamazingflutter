import 'package:flutter/material.dart';
import 'energy_manager.dart';

/// Checks for and spends energy before a replay. Returns true if the play may
/// go ahead; shows an alert (and returns false) if there isn't enough energy.
class EnergyGate {
  static Future<bool> charge(
      BuildContext context, {
        int amount = 10,
        String action = 'play again',
      }) async {
    final hasEnergy = await EnergyManager.instance.hasEnoughEnergy(required: amount);
    if (!context.mounted) return false;
    if (!hasEnergy) {
      await _alert(context, 'Not Enough Energy',
          'You need $amount energy to $action. Wait for it to regenerate!');
      return false;
    }
    final ok = await EnergyManager.instance.useEnergy(amount: amount);
    if (!context.mounted) return false;
    if (!ok) {
      await _alert(context, 'Error', 'Something went wrong. Please try again.');
      return false;
    }
    return true;
  }

  static Future<void> _alert(BuildContext context, String title, String msg) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}