// Pantallas de las funcionalidades: outfits (RF-03), colecciones (RF-05),
// estadísticas (RF-06), calendario (RF-07), inicio y perfil.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/core/theme/app_theme.dart';
import 'package:ses_wear/features/auth/data/auth_repositorio.dart';
import 'package:ses_wear/features/auth/models/perfil_usuario.dart';
import 'package:ses_wear/features/collections/screens/colecciones_screen.dart';
import 'package:ses_wear/features/home/home_screen.dart';
import 'package:ses_wear/features/outfits/data/outfits_repositorio.dart';
import 'package:ses_wear/features/outfits/models/outfit.dart';
import 'package:ses_wear/core/ia/servicio_ia.dart';
import 'package:ses_wear/core/widgets/barra_navegacion.dart';
import 'package:ses_wear/core/widgets/miniatura_prenda.dart';
import 'package:ses_wear/features/outfits/screens/crear_outfit_screen.dart';
import 'package:ses_wear/features/outfits/screens/mis_outfits_screen.dart';
import 'package:ses_wear/features/outfits/screens/outfits_screen.dart';
import 'package:ses_wear/features/outfits/widgets/generador_outfits_vista.dart';
import 'package:ses_wear/features/wardrobe/screens/armario_screen.dart';
import 'package:ses_wear/features/wardrobe/widgets/tarjeta_prenda.dart';
import 'package:ses_wear/features/outfits/widgets/tarjeta_outfit.dart';
import 'package:ses_wear/features/planner/models/plan_dia.dart';
import 'package:ses_wear/features/planner/screens/planificador_screen.dart';
import 'package:ses_wear/features/profile/screens/editar_perfil_screen.dart';
import 'package:ses_wear/features/profile/screens/perfil_screen.dart';
import 'package:ses_wear/features/stats/screens/estadisticas_screen.dart';

import '../auditoria/fakes.dart';
import 'repos_falsos.dart';

Widget _app(Widget pantalla) => MaterialApp(theme: AppTheme.theme, home: pantalla);

void _pantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

const _guardado = Outfit(id: 'o1', nombre: 'Look de prueba', prendaIds: ['s2', 'i1', 'c1'], ocasion: 'casual');

void main() {
  group('Crear outfit (RF-03)', () {
    Finder lista(String id) => find.byWidgetPredicate((w) => w is FotoPrenda && w.prenda?.id == id).first;

    Future<void> abrirCrear(WidgetTester tester, {PrendasFalso? prendas, OutfitsFalso? outfits, PlanFalso? planes}) async {
      _pantallaAlta(tester);
      await tester.pumpWidget(_app(CrearOutfitScreen(
        prendasRepositorio: prendas ?? PrendasFalso(armarioDePrueba),
        outfitsRepositorio: outfits ?? OutfitsFalso(),
        planificadorRepositorio: planes ?? PlanFalso(),
      )));
      await tester.pumpAndSettle();
    }

    Future<void> ponerNombre(WidgetTester tester, String nombre) async {
      await tester.enterText(find.byType(TextField).last, nombre);
      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();
    }

    testWidgets('elegir prendas a la izquierda las pone en el lienzo y se guarda el outfit', (tester) async {
      final outfits = OutfitsFalso();
      await abrirCrear(tester, outfits: outfits);
      expect(find.text('Tus prendas'), findsOneWidget);
      expect(find.textContaining('Toca tus prendas de la izquierda'), findsOneWidget);

      await tester.tap(lista('s2'));
      await tester.tap(lista('i1'));
      await tester.pump();
      expect(find.byTooltip('Quitar Camiseta negra'), findsOneWidget);
      expect(find.byTooltip('Quitar Jean azul'), findsOneWidget);

      await tester.tap(find.text('Guardar Outfit'));
      await tester.pumpAndSettle();
      await ponerNombre(tester, 'Casual viernes');
      final o = outfits.datos.valor.single;
      expect(o.nombre, 'Casual viernes');
      expect(o.prendaIds, ['s2', 'i1']);
      expect(o.origen, 'manual');
      expect(o.favorito, isFalse);
      expect(find.byTooltip('Quitar Jean azul'), findsNothing, reason: 'el lienzo se vacía al guardar');
    });

    testWidgets('"Añadir a favoritos" guarda el outfit como favorito', (tester) async {
      final outfits = OutfitsFalso();
      await abrirCrear(tester, outfits: outfits);
      await tester.tap(lista('s1'));
      await tester.tap(lista('i1'));
      await tester.tap(find.text('Añadir a favoritos'));
      await tester.pumpAndSettle();
      await ponerNombre(tester, 'Oficina');
      expect(outfits.datos.valor.single.favorito, isTrue);
    });

    testWidgets('"Calendario" guarda el outfit y lo programa para el día elegido', (tester) async {
      final outfits = OutfitsFalso();
      final planes = PlanFalso();
      await abrirCrear(tester, outfits: outfits, planes: planes);
      await tester.tap(lista('s1'));
      await tester.tap(lista('i1'));
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await ponerNombre(tester, 'Para hoy');
      final hoy = PlanDia.claveDe(DateTime.now());
      expect(planes.datos.valor[hoy]?.outfitNombre, 'Para hoy');
      expect(planes.datos.valor[hoy]?.prendaIds, ['s1', 'i1']);
    });

    testWidgets('con menos de 2 prendas no deja guardar', (tester) async {
      final outfits = OutfitsFalso();
      await abrirCrear(tester, outfits: outfits);
      await tester.tap(lista('s1'));
      await tester.tap(find.text('Guardar Outfit'));
      await tester.pump();
      expect(find.text('Elige al menos 2 prendas para armar el outfit.'), findsOneWidget);
      expect(outfits.datos.valor, isEmpty);
    });

    testWidgets('"Sugerir" arma el outfit automáticamente y se puede guardar', (tester) async {
      final outfits = OutfitsFalso();
      await abrirCrear(tester, outfits: outfits);
      await tester.tap(find.byTooltip('Sugerir outfit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar outfits'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este').first);
      await tester.pumpAndSettle();
      expect(find.byType(GeneradorOutfitsVista), findsNothing);
      await tester.tap(find.text('Guardar Outfit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();
      final o = outfits.datos.valor.single;
      expect(o.origen, 'local');
      expect(o.prendaIds.length, greaterThanOrEqualTo(2));
    });

    testWidgets('"Ideas con IA" le pide a la IA con las prendas y la ocasión elegidas', (tester) async {
      final outfits = OutfitsFalso(const [], const [
        Outfit(nombre: 'Idea de la IA', prendaIds: ['s1', 'i1'], origen: 'ia', explicacion: 'Funciona.'),
      ]);
      await abrirCrear(tester, outfits: outfits);
      await tester.tap(find.byTooltip('Sugerir outfit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Trabajo'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Lluvia'));
      await tester.tap(find.text('Ideas con IA'));
      await tester.pumpAndSettle();
      final pedido = outfits.pedidosIA.single;
      expect((pedido.ocasion, pedido.clima), ('trabajo', 'lluvia'));
      expect(pedido.prendaIds, {'s1', 's2', 'i1', 'c1'});
      expect(find.text('Idea de la IA'), findsOneWidget);
    });

    testWidgets('sin prendas invita a agregar la primera', (tester) async {
      await abrirCrear(tester, prendas: PrendasFalso(const []));
      expect(find.text('Añadir Prenda'), findsOneWidget);
    });
  });

  group('Mis Outfits (calendario y conjuntos)', () {
    Future<void> abrirMis(WidgetTester tester,
        {PrendasFalso? prendas, OutfitsFalso? outfits, PlanFalso? planes}) async {
      _pantallaAlta(tester);
      await tester.pumpWidget(_app(MisOutfitsScreen(
        hoy: DateTime(2026, 11, 21),
        prendasRepositorio: prendas ?? PrendasFalso(armarioDePrueba),
        outfitsRepositorio: outfits ?? OutfitsFalso([_guardado]),
        planificadorRepositorio: planes ?? PlanFalso(),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la semana y los conjuntos guardados', (tester) async {
      await abrirMis(tester);
      expect(find.text('Ideas del Día'), findsOneWidget);
      expect(find.text('16 al 22 de nov'), findsOneWidget);
      for (final d in ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do']) {
        expect(find.text(d), findsOneWidget);
      }
      expect(find.text('Conjuntos guardados'), findsOneWidget);
      expect(find.text('Look de prueba'), findsOneWidget);
    });

    testWidgets('tocar un día permite asignarle un conjunto', (tester) async {
      final planes = PlanFalso();
      await abrirMis(tester, planes: planes);
      await tester.tap(find.text('19'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Look de prueba').last);
      await tester.pumpAndSettle();
      expect(planes.datos.valor['2026-11-19']?.outfitId, 'o1');
    });

    testWidgets('el plan de hoy permite registrar que se usó', (tester) async {
      final prendas = PrendasFalso(armarioDePrueba);
      await abrirMis(tester,
          prendas: prendas,
          planes: PlanFalso({
            '2026-11-21': const PlanDia(fecha: '2026-11-21', outfitNombre: 'Look', prendaIds: ['s1', 'i1']),
          }));
      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lo usé'));
      await tester.pumpAndSettle();
      expect(prendas.usos, ['s1', 'i1']);
    });

    testWidgets('un conjunto guardado se puede marcar como favorito y usar hoy', (tester) async {
      final prendas = PrendasFalso(armarioDePrueba);
      final outfits = OutfitsFalso([_guardado]);
      await abrirMis(tester, prendas: prendas, outfits: outfits);
      await tester.tap(find.text('Look de prueba'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Marcar como favorito'));
      await tester.pumpAndSettle();
      expect(outfits.datos.valor.single.favorito, isTrue);
      await tester.tap(find.text('Lo usé hoy'));
      await tester.pumpAndSettle();
      expect(prendas.usos, ['s2', 'i1', 'c1']);
    });

    testWidgets('"ver todos" abre la lista completa con favoritos y calificación', (tester) async {
      final outfits = OutfitsFalso([_guardado]);
      await abrirMis(tester, outfits: outfits);
      await tester.tap(find.byTooltip('Ver todos los conjuntos'));
      await tester.pumpAndSettle();
      expect(find.byType(OutfitsGuardados), findsOneWidget);
      await tester.tap(find.byTooltip('4 estrellas'));
      await tester.pumpAndSettle();
      expect(outfits.datos.valor.single.calificacion, 4);
    });

    testWidgets('sin conjuntos explica cómo crearlos', (tester) async {
      await abrirMis(tester, outfits: OutfitsFalso());
      expect(find.textContaining('Arma uno en la pestaña Crear'), findsOneWidget);
    });
  });

  group('Calendario (RF-07)', () {
    testWidgets('asigna un outfit guardado al día elegido', (tester) async {
      _pantallaAlta(tester);
      final planes = PlanFalso();
      await tester.pumpWidget(_app(PlanificadorScreen(
        hoy: DateTime(2026, 11, 21),
        planificadorRepositorio: planes,
        outfitsRepositorio: OutfitsFalso([_guardado]),
        prendasRepositorio: PrendasFalso(armarioDePrueba),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Noviembre 2026'), findsOneWidget);

      await tester.tap(find.text('25'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asignar outfit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Look de prueba'));
      await tester.pumpAndSettle();

      final plan = planes.datos.valor['2026-11-25']!;
      expect(plan.outfitId, 'o1');
      expect(plan.prendaIds, ['s2', 'i1', 'c1']);
      expect(find.text('Quitar'), findsOneWidget);
    });

    testWidgets('el plan de hoy permite registrar que se usó', (tester) async {
      _pantallaAlta(tester);
      final prendas = PrendasFalso(armarioDePrueba);
      await tester.pumpWidget(_app(PlanificadorScreen(
        hoy: DateTime(2026, 11, 21),
        planificadorRepositorio: PlanFalso({
          '2026-11-21': const PlanDia(fecha: '2026-11-21', outfitNombre: 'Look', prendaIds: ['s1', 'i1']),
        }),
        outfitsRepositorio: OutfitsFalso(),
        prendasRepositorio: prendas,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lo usé'));
      await tester.pumpAndSettle();
      expect(prendas.usos, ['s1', 'i1']);
    });
  });

  group('Colecciones (RF-05)', () {
    testWidgets('crear una colección, elegir prendas y generar outfits con ella', (tester) async {
      _pantallaAlta(tester);
      final colecciones = ColeccionesFalso();
      final outfits = OutfitsFalso();
      await tester.pumpWidget(_app(ColeccionesScreen(
        prendasRepositorio: PrendasFalso(armarioDePrueba),
        coleccionesRepositorio: colecciones,
        outfitsRepositorio: outfits,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva colección'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Ropa de oficina');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(colecciones.datos.valor.single.nombre, 'Ropa de oficina');

      await tester.tap(find.text('Ropa de oficina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir prendas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camisa blanca'));
      await tester.tap(find.text('Jean azul'));
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(colecciones.datos.valor.single.prendaIds.toSet(), {'s1', 'i1'});

      await tester.tap(find.text('Generar outfits con esta colección'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar outfits'));
      await tester.pumpAndSettle();
      final tarjetas = tester.widgetList<TarjetaOutfit>(find.byType(TarjetaOutfit));
      expect(tarjetas, isNotEmpty);
      for (final t in tarjetas) {
        expect({'s1', 'i1'}.containsAll(t.outfit.prendaIds), isTrue, reason: 'solo prendas de la colección');
      }
    });
  });

  group('Estadísticas (RF-06)', () {
    testWidgets('muestra más usadas, desuso, costo por uso y paleta', (tester) async {
      _pantallaAlta(tester);
      await tester.pumpWidget(_app(EstadisticasScreen(prendasRepositorio: PrendasFalso(armarioDePrueba))));
      await tester.pumpAndSettle();
      expect(find.text('Las que más usas'), findsOneWidget);
      expect(find.text('6 usos'), findsOneWidget);
      expect(find.text('En desuso'), findsOneWidget);
      expect(find.text('\$20.000 por uso'), findsOneWidget); // 120.000 ÷ 6
      expect(find.text('Tu paleta de colores'), findsOneWidget);
      expect(find.text('Blanco'), findsOneWidget);
    });
  });

  group('Inicio', () {
    testWidgets('muestra Añadir Prenda, categorías, asistente y el armario', (tester) async {
      _pantallaAlta(tester);
      await tester.pumpWidget(_app(HomeScreen(prendasRepositorio: PrendasFalso(armarioDePrueba))));
      await tester.pumpAndSettle();
      expect(find.text('Añadir Prenda'), findsOneWidget);
      for (final c in ['Partes de arriba', 'Partes de abajo', 'Calzado', 'Accesorios']) {
        expect(find.text(c), findsOneWidget);
      }
      expect(find.text('Pregúntale a tu asistente'), findsOneWidget);
      expect(find.text('Mi Armario'), findsOneWidget);
      expect(find.byType(TarjetaPrenda), findsNWidgets(4));
    });

    testWidgets('una categoría abre el armario filtrado', (tester) async {
      _pantallaAlta(tester);
      await tester.pumpWidget(_app(HomeScreen(prendasRepositorio: PrendasFalso(armarioDePrueba))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partes de abajo'));
      await tester.pumpAndSettle();
      expect(find.byType(ArmarioScreen), findsOneWidget);
      expect(find.byType(TarjetaPrenda), findsOneWidget);
      expect(find.text('Jean azul'), findsOneWidget);
    });

    testWidgets('la tarjeta y el botón del asistente lo abren', (tester) async {
      _pantallaAlta(tester);
      var abierto = 0;
      await tester.pumpWidget(_app(HomeScreen(
        prendasRepositorio: PrendasFalso(armarioDePrueba),
        abrirAsistente: () => abierto++,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pregúntale a tu asistente'));
      await tester.tap(find.byTooltip('Asistente de estilo'));
      expect(abierto, 2);
    });

    testWidgets('con el armario vacío invita a tomar la primera foto', (tester) async {
      _pantallaAlta(tester);
      await tester.pumpWidget(_app(HomeScreen(prendasRepositorio: PrendasFalso(const []))));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tu armario está vacío'), findsOneWidget);
    });

    testWidgets('la barra inferior cambia de pestaña y abre la cámara', (tester) async {
      final elegidas = <int>[];
      var camara = 0;
      await tester.pumpWidget(_app(Scaffold(
        bottomNavigationBar: BarraNavegacion(actual: 0, alElegir: elegidas.add, alCamara: () => camara++),
      )));
      await tester.tap(find.text('Crear'));
      await tester.tap(find.text('Calendario'));
      await tester.tap(find.text('Perfil'));
      await tester.tap(find.text('Cámara'));
      expect(elegidas, [Pestanas.crear, Pestanas.calendario, Pestanas.perfil]);
      expect(camara, 1);
    });
  });

  group('Perfil', () {
    testWidgets('editar perfil guarda ciudad y preferencias', (tester) async {
      _pantallaAlta(tester);
      final db = FakeFirestore();
      final repo = AuthRepositorio(auth: FakeAuth(currentUser: FakeUser()), firestore: db);
      await tester.pumpWidget(_app(EditarPerfilScreen(
        repositorio: repo,
        perfil: const PerfilUsuario(uid: 'u1', email: 'ana@correo.com', nombre: 'Ana', telefono: '3001234567'),
      )));
      await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad (para recomendaciones según el clima)'), 'Bogotá');
      await tester.tap(find.widgetWithText(FilterChip, 'Urbano'));
      await tester.tap(find.widgetWithText(FilterChip, 'Trabajo'));
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final doc = db.docs['users/u1']!;
      expect(doc['ciudad'], 'Bogotá');
      expect((doc['preferencias'] as Map)['estilos'], ['urbano']);
      expect((doc['preferencias'] as Map)['ocasiones'], ['trabajo']);
    });

    testWidgets('eliminar la cuenta exige escribir ELIMINAR y luego llama al servidor', (tester) async {
      _pantallaAlta(tester);
      final functions = FakeFunctions({'eliminarCuenta': (_) => {'eliminada': true}});
      final auth = FakeAuth(currentUser: FakeUser());
      final repo = AuthRepositorio(
        auth: auth,
        firestore: FakeFirestore()..docs['users/u1'] = {'nombre': 'Ana'},
        functions: functions,
      );
      await tester.pumpWidget(_app(PerfilScreen(repositorio: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar mi cuenta y mis datos'));
      await tester.pumpAndSettle();

      final boton = find.widgetWithText(TextButton, 'Eliminar');
      expect(tester.widget<TextButton>(boton).onPressed, isNull, reason: 'sin escribir ELIMINAR no se habilita');
      await tester.enterText(find.byType(TextField), 'eliminar');
      await tester.pump();
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(functions.llamadas.single.$1, 'eliminarCuenta');
      expect(functions.llamadas.single.$2, {'confirmacion': 'ELIMINAR'});
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'el diálogo de progreso se cierra');
      expect(auth.currentUser, isNull, reason: 'después de borrar la cuenta se cierra la sesión');
    });

    test('si el servidor falla al eliminar, se informa con un ErrorAuth', () async {
      final repo = AuthRepositorio(
        auth: FakeAuth(currentUser: FakeUser()),
        firestore: FakeFirestore(),
        functions: FakeFunctions({
          'eliminarCuenta': (_) => throw FirebaseFunctionsException(code: 'internal', message: 'Falló.'),
        }),
      );
      await expectLater(repo.eliminarCuenta(), throwsA(isA<ErrorAuth>().having((e) => e.mensaje, 'mensaje', 'Falló.')));
    });
  });

  group('OutfitsRepositorio.generarConIA', () {
    test('pide a la IA con las prendas y descarta ids inventados', () async {
      final ia = IAFalsa(json: {
        'outfits': [
          {'nombre': 'Oficina', 'prendaIds': ['s1', 'i1', 'inventada'], 'explicacion': 'Sobrio.'},
          {'nombre': 'Solo una', 'prendaIds': ['s1']},
        ],
      });
      final repo = OutfitsRepositorio(firestore: FakeFirestore(), ia: ia, auth: FakeAuth(currentUser: FakeUser()));
      final r = await repo.generarConIA(prendas: armarioDePrueba, ocasion: 'trabajo', clima: 'frío', excluir: const [
        ['x', 'y'],
      ]);
      expect(r.single.prendaIds, ['s1', 'i1']);
      expect(r.single.origen, 'ia');
      final pedido = ia.pedidosJson.single.pedido.texto;
      expect(pedido, contains('Ocasión: trabajo. Clima: frío.'));
      expect(pedido, contains('- id i1: Jean azul'));
      expect(pedido, contains('- x, y'));
    });

    test('con menos de 2 prendas avisa sin llamar a la IA', () async {
      final ia = IAFalsa();
      final repo = OutfitsRepositorio(firestore: FakeFirestore(), ia: ia, auth: FakeAuth(currentUser: FakeUser()));
      await expectLater(repo.generarConIA(prendas: [armarioDePrueba.first], ocasion: 'casual'), throwsA(isA<ErrorIA>()));
      expect(ia.pedidosJson, isEmpty);
    });
  });
}
