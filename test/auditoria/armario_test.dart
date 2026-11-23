// Auditoría del armario virtual (RF-01 identificación con IA, RF-02 CRUD).
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:ses_wear/core/ia/servicio_ia.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/features/wardrobe/data/prendas_repositorio.dart';
import 'package:ses_wear/features/wardrobe/models/prenda.dart';
import 'package:ses_wear/features/wardrobe/screens/armario_screen.dart';
import 'package:ses_wear/features/wardrobe/screens/detalle_prenda_screen.dart';
import 'package:ses_wear/features/wardrobe/screens/nueva_prenda_screen.dart';
import 'package:ses_wear/features/wardrobe/widgets/tarjeta_prenda.dart';

import 'fakes.dart';

// PNG de 1×1 px válido para Image.memory.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

class RepoPrendasFalso extends PrendasRepositorio {
  RepoPrendasFalso({
    this.prendas = const [],
    this.errorObservar,
    this.errorEliminar,
    this.errorGuardar,
    this.errorIA,
    this.resultadoIA,
    this.errorFondo,
  }) : super(functions: FakeFunctions(), firestore: FakeFirestore(), storage: FakeStorage());

  final List<Prenda> prendas;
  final Object? errorObservar;
  final Object? errorEliminar;
  final Object? errorGuardar;
  final Object? errorIA;
  final ResultadoIdentificacion? resultadoIA;
  final Object? errorFondo;
  final eliminadas = <Prenda>[];
  final guardadas = <(Prenda, String)>[];
  final actualizadas = <Prenda>[];
  final usos = <String>[];

  @override
  Future<void> actualizar(Prenda prenda) async => actualizadas.add(prenda);

  @override
  Future<void> registrarUso(Iterable<String> prendaIds) async => usos.addAll(prendaIds);

  @override
  Stream<List<Prenda>> observar() =>
      errorObservar != null ? Stream.error(errorObservar!) : Stream.value(prendas);

  @override
  Future<void> eliminar(Prenda prenda) async {
    if (errorEliminar != null) throw errorEliminar!;
    eliminadas.add(prenda);
  }

  @override
  Future<ResultadoIdentificacion> identificar(Uint8List foto, {String tipo = 'image/jpeg'}) async {
    if (errorIA != null) throw errorIA!;
    return resultadoIA!;
  }

  @override
  Future<ResultadoFondo> quitarFondo(Uint8List foto, {String tipo = 'image/jpeg'}) async {
    if (errorFondo != null) throw errorFondo!;
    return ResultadoFondo(foto: _png, tipo: 'image/png', fotosGratisRestantes: 49);
  }

  @override
  Future<Prenda> guardar(Prenda prenda, Uint8List foto, {String tipo = 'image/jpeg'}) async {
    if (errorGuardar != null) throw errorGuardar!;
    guardadas.add((prenda, tipo));
    return prenda.copyWith(id: 'nueva');
  }
}

const _jean = Prenda(id: 'p1', nombre: 'Jean azul', tipo: 'inferior', categoria: 'jean', colorPrimario: 'azul');

final _iaJean = ResultadoIdentificacion(
  esPrenda: true,
  prenda: Prenda.desdeIA({
    'nombre': 'Jean azul clásico',
    'tipo': 'inferior',
    'categoria': 'jean',
    'colorPrimario': 'azul',
    'tela': 'denim',
    'formalidad': 'casual',
    'estacion': 'todo el año',
    'etiquetas': ['tiro alto'],
  }),
);

void main() {
  group('ArmarioScreen', () {
    Widget app(RepoPrendasFalso repo) => MaterialApp(home: ArmarioScreen(repositorio: repo));

    testWidgets('armario vacío muestra la invitación a agregar prendas', (tester) async {
      await tester.pumpWidget(app(RepoPrendasFalso()));
      await tester.pump();
      expect(find.textContaining('Tu armario está vacío'), findsOneWidget);
      expect(find.text('Agregar prenda'), findsOneWidget);
    });

    testWidgets('muestra las prendas guardadas', (tester) async {
      await tester.pumpWidget(app(RepoPrendasFalso(prendas: [_jean])));
      await tester.pump();
      expect(find.byType(TarjetaPrenda), findsOneWidget);
      expect(find.text('Jean azul'), findsOneWidget);
      expect(find.text('jean · azul'), findsOneWidget);
    });

    testWidgets('error al leer Firestore muestra un mensaje', (tester) async {
      await tester.pumpWidget(app(RepoPrendasFalso(errorObservar: Exception('permiso'))));
      await tester.pump();
      expect(find.text('No se pudo cargar tu armario.'), findsOneWidget);
    });

    testWidgets('mantener presionada una prenda permite eliminarla', (tester) async {
      final repo = RepoPrendasFalso(prendas: [_jean]);
      await tester.pumpWidget(app(repo));
      await tester.pump();
      await tester.longPress(find.byType(TarjetaPrenda));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(repo.eliminadas.single.id, 'p1');
    });

    testWidgets('Regresión: si falla eliminar, debe avisar al usuario', (tester) async {
      final repo = RepoPrendasFalso(prendas: [_jean], errorEliminar: Exception('sin conexión'));
      await tester.pumpWidget(app(repo));
      await tester.pump();
      await tester.longPress(find.byType(TarjetaPrenda));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('RF-02: tocar una prenda abre su detalle y se puede editar', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final repo = RepoPrendasFalso(prendas: [_jean]);
      await tester.pumpWidget(app(repo));
      await tester.pump();
      await tester.tap(find.byType(TarjetaPrenda));
      await tester.pumpAndSettle();
      expect(find.byType(DetallePrendaScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Jean azul'), 'Jean favorito');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Precio en pesos (opcional, para el costo por uso)'), '120.000');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final editada = repo.actualizadas.single;
      expect(editada.id, 'p1');
      expect(editada.nombre, 'Jean favorito');
      expect(editada.precio, 120000);
    });

    testWidgets('RF-02: "La usé hoy" registra un uso', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final repo = RepoPrendasFalso(prendas: [_jean]);
      await tester.pumpWidget(app(repo));
      await tester.pump();
      await tester.tap(find.byType(TarjetaPrenda));
      await tester.pumpAndSettle();
      await tester.tap(find.text('La usé hoy'));
      await tester.pumpAndSettle();
      expect(repo.usos, ['p1']);
    });

    testWidgets('RF-02: la búsqueda y el filtro por tipo reducen la lista', (tester) async {
      const camiseta = Prenda(id: 'p2', nombre: 'Camiseta blanca', tipo: 'superior', colorPrimario: 'blanco');
      await tester.pumpWidget(app(RepoPrendasFalso(prendas: [_jean, camiseta])));
      await tester.pump();
      expect(find.byType(TarjetaPrenda), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'blanca');
      await tester.pump();
      expect(find.byType(TarjetaPrenda), findsOneWidget);
      expect(find.text('Camiseta blanca'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Inferior'));
      await tester.pump();
      expect(find.byType(TarjetaPrenda), findsOneWidget);
      expect(find.text('Jean azul'), findsOneWidget);
    });
  });

  group('NuevaPrendaScreen', () {
    late List<bool?> resultados;

    Future<void> abrir(WidgetTester tester, RepoPrendasFalso repo, {String tipo = 'image/jpeg', bool quitarFondo = false}) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      resultados = [];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultados.add(await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => NuevaPrendaScreen(foto: _png, tipoImagen: tipo, repositorio: repo, quitarFondoAlAbrir: quitarFondo),
              )));
            },
            child: const Text('abrir'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('la IA llena el formulario', (tester) async {
      await abrir(tester, RepoPrendasFalso(resultadoIA: _iaJean));
      expect(find.text('Jean azul clásico'), findsOneWidget);
      expect(find.text('denim'), findsOneWidget);
      expect(find.textContaining('La IA llenó los datos'), findsOneWidget);
    });

    testWidgets('si la foto no es una prenda avisa y deja llenar a mano', (tester) async {
      await abrir(tester, RepoPrendasFalso(resultadoIA: ResultadoIdentificacion(
        esPrenda: false, prenda: Prenda.desdeIA(const {}))));
      expect(find.textContaining('No reconocí ninguna prenda'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('si la Cloud Function falla muestra su mensaje', (tester) async {
      await abrir(tester, RepoPrendasFalso(
        errorIA: const ErrorIA('Se acabó el cupo.')));
      expect(find.textContaining('Se acabó el cupo.'), findsOneWidget);
    });

    testWidgets('no deja guardar sin nombre', (tester) async {
      final repo = RepoPrendasFalso(resultadoIA: ResultadoIdentificacion(
        esPrenda: false, prenda: Prenda.desdeIA(const {})));
      await abrir(tester, repo);
      await tester.tap(find.text('Guardar en mi armario'));
      await tester.pumpAndSettle();
      expect(repo.guardadas, isEmpty);
      expect(find.textContaining('nombre'), findsWidgets);
    });

    testWidgets('Regresión: el error de validación dice "Escribe el nombre"', (tester) async {
      await abrir(tester, RepoPrendasFalso(resultadoIA: ResultadoIdentificacion(
        esPrenda: false, prenda: Prenda.desdeIA(const {}))));
      await tester.tap(find.text('Guardar en mi armario'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe el nombre'), findsOneWidget);
    });

    testWidgets('guardar envía los datos normalizados y cierra la pantalla', (tester) async {
      final repo = RepoPrendasFalso(resultadoIA: _iaJean);
      await abrir(tester, repo);
      await tester.enterText(find.widgetWithText(TextFormField, 'Etiquetas (separadas por coma)'), 'a, , b ');
      await tester.tap(find.text('Guardar en mi armario'));
      await tester.pumpAndSettle();
      final (prenda, tipo) = repo.guardadas.single;
      expect(prenda.nombre, 'Jean azul clásico');
      expect(prenda.etiquetas, ['a', 'b']);
      expect(prenda.identificadaPorIA, isTrue);
      expect(tipo, 'image/jpeg');
      expect(resultados, [true]);
    });

    testWidgets('quitar el fondo hace que se guarde el PNG', (tester) async {
      final repo = RepoPrendasFalso(resultadoIA: _iaJean);
      await abrir(tester, repo);
      await tester.tap(find.textContaining('Quitar fondo'));
      await tester.pumpAndSettle();
      expect(find.text('Usar foto original'), findsOneWidget);
      await tester.tap(find.text('Guardar en mi armario'));
      await tester.pumpAndSettle();
      expect(repo.guardadas.single.$2, 'image/png');
    });

    testWidgets('al abrir quita el fondo automáticamente y guarda el PNG', (tester) async {
      final repo = RepoPrendasFalso(resultadoIA: _iaJean);
      await abrir(tester, repo, quitarFondo: true);
      expect(find.text('Usar foto original'), findsOneWidget);
      await tester.tap(find.text('Guardar en mi armario'));
      await tester.pumpAndSettle();
      expect(repo.guardadas.single.$2, 'image/png');
    });

    testWidgets('si el servicio de quitar fondo no está publicado lo explica y deja reintentar', (tester) async {
      final repo = RepoPrendasFalso(
        resultadoIA: _iaJean,
        errorFondo: FirebaseFunctionsException(code: 'not-found', message: 'NOT_FOUND'),
      );
      await abrir(tester, repo, quitarFondo: true);
      expect(find.textContaining('aún no está publicado'), findsOneWidget);
      expect(find.text('Reintentar quitar fondo'), findsOneWidget);
      // Igual se puede guardar con la foto original.
      await tester.tap(find.text('Guardar en mi armario'));
      await tester.pumpAndSettle();
      expect(repo.guardadas.single.$2, 'image/jpeg');
    });

    testWidgets('si falla guardar, avisa y permite reintentar', (tester) async {
      final repo = RepoPrendasFalso(resultadoIA: _iaJean, errorGuardar: Exception('storage'));
      await abrir(tester, repo);
      await tester.tap(find.text('Guardar en mi armario'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo guardar la prenda. Inténtalo de nuevo.'), findsOneWidget);
      expect(find.text('Guardar en mi armario'), findsOneWidget);
    });
  });
}
