import 'package:flutter/material.dart';

/// 温度项 — 蓝色编号 badge + 温度文字
class TempItem extends StatelessWidget {
  final String num;
  final String temp;
  final String target;
  final bool active;

  const TempItem({
    super.key,
    required this.num,
    required this.temp,
    required this.target,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        active ? const Color(0xFF242424) : const Color(0xFF999999);
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1B50FF),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$temp /$target℃',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// 热床项
class BedItem extends StatelessWidget {
  const BedItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF1B50FF),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.waves, size: 10, color: Colors.white),
        ),
        const SizedBox(width: 6),
        const Text(
          '_ /_℃',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }
}

/// LED 项
class LedItem extends StatelessWidget {
  const LedItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF1B50FF),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          alignment: Alignment.center,
          child:
              const Icon(Icons.lightbulb_outline, size: 10, color: Colors.white),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.circle, size: 8, color: Color(0xFF0ED400)),
        const SizedBox(width: 4),
        const Text(
          'LED',
          style: TextStyle(fontSize: 10, color: Color(0xFF242424)),
        ),
      ],
    );
  }
}

/// 风扇项
class FanItem extends StatelessWidget {
  const FanItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF1B50FF),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.air, size: 10, color: Colors.white),
        ),
        const SizedBox(width: 6),
        const Text(
          '100%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF242424),
          ),
        ),
      ],
    );
  }
}
