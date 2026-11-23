// Modo claro y oscuro (RNF-02).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ses_wear/core/theme/app_theme.dart';
import 'package:ses_wear/core/theme/controlador_tema.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pantalla con estado que lee los colores de AppTheme directamente.
class _Contador extends StatefulWidget {
  const _Contador();
  @override
  State<_Contador> createState() => _ContadorState();
}

class _ContadorState extends State<_Contador> {
  int n = 0;
  @override
  Widget build(BuildContext context) => ColoredBox(
        key: const Key('fondo'),
        color: AppTheme.background,
        child: TextButton(onPressed: () => setState(() => n++), child: Text('toques $n')),
      );
}

void main() {
  tearDown(() => AppTheme.oscuro = true);

  test('modo según el celular, claro u oscuro', () {
    expect(ControladorTema.esOscuro(ModoTema.sistema, Brightness.dark), isTrue);
    expect(ControladorTema.esOscuro(ModoTema.sistema, Brightness.light), isFalse);
    expect(ControladorTema.esOscuro(ModoTema.claro, Brightness.dark), isFalse);
    expect(ControladorTema.esOscuro(ModoTema.oscuro, Brightness.light), isTrue);
  });

  test('los colores cambian con el modo', () {
    AppTheme.oscuro = true;
    final fondoOscuro = AppTheme.background;
    expect(AppTheme.theme.brightness, Brightness.dark);
    AppTheme.oscuro = false;
    expect(AppTheme.background, isNot(fondoOscuro));
    expect(AppTheme.theme.brightness, Brightness.light);
  });

  test('guarda y recupera el modo elegido', () async {
    SharedPreferences.setMockInitialValues({});
    await ControladorTema().cambiar(ModoTema.claro);
    final otro = ControladorTema();
    await otro.cargar();
    expect(otro.value, ModoTema.claro);
  });

  testWidgets('cambiar a claro repinta la pantalla abierta sin perder su estado', (tester) async {
    final controlador = ControladorTema(ModoTema.oscuro);
    await tester.pumpWidget(AplicarTema(
      controlador: controlador,
      builder: (context, tema) => MaterialApp(theme: tema, home: const Scaffold(body: _Contador())),
    ));
    await tester.tap(find.text('toques 0'));
    await tester.pump();
    Color fondo() => tester.widget<ColoredBox>(find.byKey(const Key('fondo'))).color;
    final oscuro = fondo();

    controlador.value = ModoTema.claro;
    await tester.pumpAndSettle(); // MaterialApp anima el cambio de tema
    expect(fondo(), isNot(oscuro));
    expect(Theme.of(tester.element(find.byType(_Contador))).brightness, Brightness.light);
    expect(find.text('toques 1'), findsOneWidget, reason: 'no se pierde el estado');
  });
}
