// Auditoría de la pantalla del asistente (RF-04).
import 'dart:async';

import 'package:ses_wear/core/ia/servicio_ia.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/features/assistant/data/asistente_repositorio.dart';
import 'package:ses_wear/features/assistant/models/mensaje.dart';
import 'package:ses_wear/features/assistant/screens/chat_screen.dart';
import 'package:ses_wear/features/assistant/widgets/burbuja_mensaje.dart';

import 'fakes.dart';

class RepoChatFalso extends AsistenteRepositorio {
  RepoChatFalso({this.historial = const [], this.idGuardado, this.errorEnvio, this._cargaLenta})
      : super(ia: IAFalsa(), firestore: FakeFirestore(), auth: FakeAuth());

  final List<Mensaje> historial;
  final String? idGuardado;
  final Object? errorEnvio;
  final Completer<String?>? _cargaLenta;
  final enviados = <(List<Mensaje>, String?)>[];

  @override
  Future<String?> ultimaConversacionId() => _cargaLenta?.future ?? Future.value(idGuardado);

  @override
  Future<List<Mensaje>> cargarMensajes(String conversacionId) async => historial;

  @override
  Future<RespuestaAsistente> enviar({required List<Mensaje> historial, String? conversacionId}) async {
    enviados.add((historial, conversacionId));
    if (errorEnvio != null) throw errorEnvio!;
    return RespuestaAsistente(texto: 'Respuesta ${enviados.length}', rechazado: false, conversacionId: 'c-nueva');
  }
}

Widget _app(RepoChatFalso repo) => MaterialApp(home: ChatScreen(repositorio: repo));

Future<void> _escribirYEnviar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.tap(find.byTooltip('Enviar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin historial muestra sugerencias y una sugerencia se envía', (tester) async {
    final repo = RepoChatFalso();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNWidgets(3));
    await tester.tap(find.text('Arma un outfit para la U'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Respuesta 1', findRichText: true), findsOneWidget);
  });

  testWidgets('carga la última conversación guardada', (tester) async {
    final repo = RepoChatFalso(idGuardado: 'c1', historial: const [
      Mensaje(rol: RolMensaje.usuario, texto: 'Hola'),
      Mensaje(rol: RolMensaje.asistente, texto: '¡Hola! ¿Qué te pongo hoy?'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.byType(BurbujaMensaje), findsNWidgets(2));
  });

  testWidgets('envía el historial y reutiliza el id de conversación', (tester) async {
    final repo = RepoChatFalso(idGuardado: 'c1', historial: const [
      Mensaje(rol: RolMensaje.usuario, texto: 'Hola'),
      Mensaje(rol: RolMensaje.asistente, texto: 'Hola!'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await _escribirYEnviar(tester, '¿Qué combina con mi jean?');
    expect(repo.enviados.single.$1.length, 3);
    expect(repo.enviados.single.$2, 'c1');
    expect(find.textContaining('Respuesta 1', findRichText: true), findsOneWidget);
  });

  testWidgets('si falla, muestra el error y devuelve el texto al campo', (tester) async {
    final repo = RepoChatFalso(
        errorEnvio: const ErrorIA('Cupo agotado.'));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await _escribirYEnviar(tester, 'Hola');
    expect(find.text('Cupo agotado.'), findsOneWidget);
    expect(find.byType(BurbujaMensaje), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Hola');
  });

  testWidgets('nueva conversación limpia y no reutiliza el id', (tester) async {
    final repo = RepoChatFalso(idGuardado: 'c1', historial: const [
      Mensaje(rol: RolMensaje.usuario, texto: 'Hola'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nueva conversación'));
    await tester.pumpAndSettle();
    expect(find.byType(BurbujaMensaje), findsNothing);
    await _escribirYEnviar(tester, 'Otra pregunta');
    expect(repo.enviados.single.$2, isNull);
  });

  testWidgets('Regresión: si se envía un mensaje mientras carga el historial, el mensaje y la respuesta se conservan',
      (tester) async {
    final carga = Completer<String?>();
    final repo = RepoChatFalso(cargaLenta: carga, historial: const [
      Mensaje(rol: RolMensaje.usuario, texto: 'Mensaje viejo'),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pump();
    // El campo de texto y el botón Enviar están activos aunque el historial siga cargando.
    await tester.enterText(find.byType(TextField), 'Pregunta nueva');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();
    await tester.pump();
    carga.complete('c-vieja'); // termina de cargar el historial
    await tester.pumpAndSettle();
    expect(find.textContaining('Pregunta nueva', findRichText: true), findsOneWidget, reason: 'la pregunta del usuario se borró de la pantalla');
    expect(find.textContaining('Respuesta 1', findRichText: true), findsOneWidget, reason: 'la respuesta del asistente se borró de la pantalla');
  });
}
