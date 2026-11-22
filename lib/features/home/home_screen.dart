import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Pantalla de inicio (provisional).
///
/// `main.dart` ya importaba este archivo, pero no estaba en el repositorio y la
/// app no compilaba. Si ya tienes tu propia versión local, conserva la tuya.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SES Wear')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tu estilo, más inteligente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
