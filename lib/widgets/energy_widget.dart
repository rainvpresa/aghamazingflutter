import 'package:flutter/material.dart';
import 'dart:async';
import '../services/energy_manager.dart';

class EnergyWidget extends StatefulWidget {
  final TextStyle? textStyle;
  final double? iconSize;
  final Color? iconColor;

  const EnergyWidget({
    super.key,
    this.textStyle,
    this.iconSize,
    this.iconColor,
  });

  @override
  State<EnergyWidget> createState() => _EnergyWidgetState();
}

class _EnergyWidgetState extends State<EnergyWidget> {
  final EnergyManager _energyManager = EnergyManager.instance;

  int _currentEnergy = 0;
  String _nextEnergyTime = '00:00';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadEnergy();
    _startTimer();
  }

  Future<void> _loadEnergy() async {
    final energy = await _energyManager.getCurrentEnergy();
    final timeNext = await _energyManager.getTimeUntilNextEnergyFormatted();

    if (mounted) {
      setState(() {
        _currentEnergy = energy;
        _nextEnergyTime = timeNext;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _loadEnergy();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.bolt,
          color: widget.iconColor ?? Colors.amber,
          size: widget.iconSize ?? 24,
        ),
        const SizedBox(width: 4),
        Text(
          '$_currentEnergy',
          style: widget.textStyle ?? const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_currentEnergy < EnergyManager.maxEnergy) ...[
          const SizedBox(width: 4),
          Text(
            '(+1 in $_nextEnergyTime)',
            style: (widget.textStyle ?? const TextStyle(fontSize: 12))
                .copyWith(fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ],
    );
  }
}