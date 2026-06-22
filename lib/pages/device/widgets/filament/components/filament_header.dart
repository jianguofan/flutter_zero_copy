import 'package:flutter/material.dart';
import '../../shared/header_bar.dart';

/// 耗材 Header
class FilamentHeader extends StatelessWidget {
  const FilamentHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const HeaderBar(
      child: Row(
        children: [
          Text('耗材',
              style:
                  TextStyle(fontSize: 14, color: Color(0xFF242424))),
          Spacer(),
          Icon(Icons.info_outline,
              size: 18, color: Color(0xFF8F8F8F)),
        ],
      ),
    );
  }
}
