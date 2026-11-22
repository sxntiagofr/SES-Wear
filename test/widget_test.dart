import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/features/assistant/models/mensaje.dart';
import 'package:ses_wear/features/assistant/widgets/burbuja_mensaje.dart';

void main() {
  testWidgets('La burbuja del asistente muestra el texto sin los asteriscos',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BurbujaMensaje(
            mensaje: Mensaje(
              rol: RolMensaje.asistente,
              texto: '**Sí sirve** para la U',
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Sí sirve para la U', findRichText: true), findsOneWidget);
    expect(find.textContaining('**', findRichText: true), findsNothing);
  });

  test('El mensaje se convierte al formato de la Cloud Function', () {
    const mensaje = Mensaje(rol: RolMensaje.usuario, texto: 'Hola');
    expect(mensaje.aFuncion(), {'rol': 'usuario', 'texto': 'Hola'});
  });
}
