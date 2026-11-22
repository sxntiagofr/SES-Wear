import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/mensaje.dart';

/// Burbuja de un mensaje del chat. Los del usuario van a la derecha.
class BurbujaMensaje extends StatelessWidget {
  const BurbujaMensaje({super.key, required this.mensaje});

  final Mensaje mensaje;

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.esDelUsuario;
    return Align(
      alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: esUsuario ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(esUsuario ? 18 : 4),
            bottomRight: Radius.circular(esUsuario ? 4 : 18),
          ),
        ),
        child: Text.rich(
          _conNegritas(
            mensaje.tieneFoto ? '📷 ${mensaje.texto}' : mensaje.texto,
            esUsuario ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  /// El asistente resalta palabras con **negrita** (formato Markdown sencillo).
  static TextSpan _conNegritas(String texto, Color color) {
    final partes = texto.split('**');
    return TextSpan(
      style: TextStyle(color: color, fontSize: 15, height: 1.35),
      children: [
        for (var i = 0; i < partes.length; i++)
          TextSpan(
            text: partes[i],
            style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
      ],
    );
  }
}
