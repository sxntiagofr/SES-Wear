// Lógica pura de las funcionalidades: filtros del armario (RF-02), generador
// de outfits (RF-03), estadísticas (RF-06) y modelos de Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/features/collections/models/coleccion.dart';
import 'package:ses_wear/features/outfits/logic/generador_outfits.dart';
import 'package:ses_wear/features/outfits/models/outfit.dart';
import 'package:ses_wear/features/planner/models/plan_dia.dart';
import 'package:ses_wear/features/stats/logic/estadisticas.dart';
import 'package:ses_wear/features/wardrobe/models/prenda.dart';
import 'package:ses_wear/features/wardrobe/widgets/campos_prenda.dart';

Prenda _p(String id, String tipo,
        {String color = 'negro',
        String formalidad = 'casual',
        String estacion = 'todo el año',
        int usos = 0,
        double? precio,
        DateTime? ultimoUso,
        DateTime? creada,
        String? nombre}) =>
    Prenda(
      id: id,
      nombre: nombre ?? '$tipo $id',
      tipo: tipo,
      colorPrimario: color,
      formalidad: formalidad,
      estacion: estacion,
      vecesUsada: usos,
      precio: precio,
      ultimoUso: ultimoUso,
      fechaCreacion: creada,
    );

void main() {
  group('FiltroPrendas (RF-02)', () {
    final prendas = [
      _p('1', 'superior', color: 'blanco', nombre: 'Camisa Oxford', estacion: 'calor'),
      _p('2', 'inferior', color: 'azul', nombre: 'Jean clásico', formalidad: 'semiformal'),
      _p('3', 'abrigo', color: 'negro', nombre: 'Chaqueta de cuero', estacion: 'frío'),
    ];

    test('sin filtros devuelve todo', () {
      expect(const FiltroPrendas().aplicar(prendas), hasLength(3));
      expect(const FiltroPrendas().activo, isFalse);
    });

    test('busca sin importar tildes ni mayúsculas', () {
      expect(const FiltroPrendas(texto: 'CLASICO').aplicar(prendas).single.id, '2');
      expect(const FiltroPrendas(texto: 'cuero').aplicar(prendas).single.id, '3');
    });

    test('filtra por tipo, color, formalidad y estación', () {
      expect(const FiltroPrendas(tipo: 'abrigo').aplicar(prendas).single.id, '3');
      expect(const FiltroPrendas(color: 'Azul').aplicar(prendas).single.id, '2');
      expect(const FiltroPrendas(formalidad: 'semiformal').aplicar(prendas).single.id, '2');
      // "todo el año" sirve en cualquier estación.
      expect(const FiltroPrendas(estacion: 'frío').aplicar(prendas).map((p) => p.id), ['2', '3']);
    });

    test('los filtros se combinan y se cuentan', () {
      const f = FiltroPrendas(tipo: 'superior', color: 'negro');
      expect(f.aplicar(prendas), isEmpty);
      expect(f.cantidad, 2);
      expect(f.conColor(null).cantidad, 1);
    });

    test('lista los colores del armario sin repetir', () {
      expect(FiltroPrendas.coloresDe(prendas), ['azul', 'blanco', 'negro']);
    });
  });

  group('GeneradorOutfits (RF-03)', () {
    const g = GeneradorOutfits();

    test('arma superior + inferior + calzado', () {
      final outfits = g.generar(
        prendas: [_p('s', 'superior'), _p('i', 'inferior'), _p('c', 'calzado')],
        ocasion: 'casual',
      );
      expect(outfits.single.prendaIds.toSet(), {'s', 'i', 'c'});
      expect(outfits.single.origen, 'local');
      expect(outfits.single.explicacion, isNotEmpty);
    });

    test('un enterizo no necesita inferior', () {
      final outfits = g.generar(prendas: [_p('e', 'enterizo'), _p('c', 'calzado')], ocasion: 'casual');
      expect(outfits.single.prendaIds.toSet(), {'e', 'c'});
    });

    test('respeta la formalidad de la ocasión', () {
      final prendas = [
        _p('s1', 'superior', formalidad: 'formal'),
        _p('s2', 'superior', formalidad: 'deportivo'),
        _p('i1', 'inferior', formalidad: 'formal'),
        _p('i2', 'inferior', formalidad: 'deportivo'),
      ];
      final trabajo = g.generar(prendas: prendas, ocasion: 'trabajo', cantidad: 1);
      expect(trabajo.single.prendaIds.toSet(), {'s1', 'i1'});
      final deporte = g.generar(prendas: prendas, ocasion: 'deportivo', cantidad: 1);
      expect(deporte.single.prendaIds.toSet(), {'s2', 'i2'});
    });

    test('con frío agrega abrigo y no usa ropa de calor', () {
      final outfits = g.generar(
        prendas: [
          _p('s1', 'superior', estacion: 'calor'),
          _p('s2', 'superior'),
          _p('i', 'inferior'),
          _p('a', 'abrigo', estacion: 'frío'),
        ],
        ocasion: 'casual',
        clima: 'frío',
      );
      expect(outfits.single.prendaIds.toSet(), {'s2', 'i', 'a'});
    });

    test('prefiere colores que combinan (máximo 2 fuertes)', () {
      final outfits = g.generar(
        prendas: [
          _p('rojo', 'superior', color: 'rojo'),
          _p('negro', 'superior', color: 'negro'),
          _p('verde', 'inferior', color: 'verde'),
          _p('amarillo', 'calzado', color: 'amarillo'),
        ],
        ocasion: 'casual',
        cantidad: 1,
      );
      expect(outfits.single.prendaIds, contains('negro'));
      expect(GeneradorOutfits.coloresFuertes([_p('a', 'x', color: 'rojo'), _p('b', 'x', color: 'negro')]), 1);
    });

    test('prefiere prendas poco usadas (consumo responsable)', () {
      final outfits = g.generar(
        prendas: [_p('vieja', 'superior', usos: 30), _p('nueva', 'superior'), _p('i', 'inferior')],
        ocasion: 'casual',
        cantidad: 1,
      );
      expect(outfits.single.prendaIds, contains('nueva'));
    });

    test('"otras opciones" no repite combinaciones ya mostradas', () {
      final prendas = [_p('s1', 'superior'), _p('s2', 'superior'), _p('i', 'inferior')];
      final primeros = g.generar(prendas: prendas, ocasion: 'casual', cantidad: 1);
      final otros = g.generar(prendas: prendas, ocasion: 'casual', cantidad: 1, excluir: primeros.map((o) => o.clave));
      expect(otros.single.clave, isNot(primeros.single.clave));
      final agotados = g.generar(
          prendas: prendas, ocasion: 'casual', excluir: [...primeros, ...otros].map((o) => o.clave));
      expect(agotados, isEmpty);
    });

    test('sin prendas suficientes no inventa outfits', () {
      expect(g.generar(prendas: [_p('s', 'superior')], ocasion: 'casual'), isEmpty);
      expect(g.generar(prendas: const [], ocasion: 'fiesta'), isEmpty);
    });

    test('responde en menos de 1 segundo con un armario grande (RNF-01)', () {
      final prendas = [
        for (var i = 0; i < 60; i++) _p('s$i', 'superior', color: i.isEven ? 'negro' : 'rojo'),
        for (var i = 0; i < 60; i++) _p('i$i', 'inferior'),
        for (var i = 0; i < 30; i++) _p('c$i', 'calzado'),
        for (var i = 0; i < 20; i++) _p('a$i', 'abrigo'),
      ];
      // Una pasada previa para que la medición no incluya la compilación JIT
      // de la prueba (en el celular la app ya va compilada).
      g.generar(prendas: prendas, ocasion: 'casual', clima: 'frío', cantidad: 5);
      final reloj = Stopwatch()..start();
      final outfits = g.generar(prendas: prendas, ocasion: 'casual', clima: 'frío', cantidad: 5);
      expect(reloj.elapsedMilliseconds, lessThan(1000));
      expect(outfits, hasLength(5));
    });
  });

  group('Estadisticas (RF-06)', () {
    final hoy = DateTime(2026, 11, 21);

    test('más usadas, en desuso, costo por uso y paleta', () {
      final e = Estadisticas.calcular([
        _p('a', 'superior', usos: 10, precio: 50000, color: 'negro', ultimoUso: hoy),
        _p('b', 'inferior', usos: 2, precio: 100000, color: 'azul', ultimoUso: DateTime(2026, 8, 1)),
        _p('c', 'calzado', color: 'negro', creada: DateTime(2026, 1, 1)),
        _p('d', 'abrigo', color: 'negro', creada: DateTime(2026, 11, 15)), // recién comprada
      ], hoy: hoy);

      expect(e.totalPrendas, 4);
      expect(e.totalUsos, 12);
      expect(e.masUsadas.map((p) => p.id), ['a', 'b']);
      expect(e.enDesuso.map((p) => p.id), ['c', 'b']); // nunca usada y sin uso hace +60 días
      expect(e.costoPorUso.map((p) => p.id), ['b', 'a']); // 50.000 por uso vs 5.000
      expect(e.costoPorUso.last.costoPorUso, 5000);
      expect(e.paleta.first, (color: 'negro', cantidad: 3));
      expect(e.porcentajeEnUso, 0.5);
    });

    test('armario vacío no falla', () {
      final e = Estadisticas.calcular(const [], hoy: hoy);
      expect(e.totalPrendas, 0);
      expect(e.porcentajeEnUso, 0);
    });
  });

  group('Modelos', () {
    test('Prenda lee precio y último uso, y tolera datos raros', () {
      final p = Prenda.desdeFirestore('x', {
        'nombre': 'Saco',
        'precio': '80000',
        'ultimoUso': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'vecesUsada': 4,
      });
      expect(p.precio, 80000);
      expect(p.ultimoUso, DateTime(2026, 11, 1));
      expect(p.costoPorUso, 20000);
      expect(Prenda.desdeFirestore('y', {'precio': -5}).precio, isNull);
    });

    test('editar una prenda no toca usos ni foto', () {
      const p = Prenda(id: 'x', nombre: 'Saco', tipo: 'abrigo', vecesUsada: 3, fotoUrl: 'http://foto', precio: 10);
      final datos = p.aFirestoreEditable();
      expect(datos.containsKey('vecesUsada'), isFalse);
      expect(datos.containsKey('fotoUrl'), isFalse);
      expect(p.copyWith(quitarPrecio: true).precio, isNull);
    });

    test('el formulario entiende precios con puntos y conserva lo no editable', () {
      final f = FormularioPrenda()..llenar(const Prenda(id: 'x', nombre: 'Jean', tipo: 'inferior', vecesUsada: 7));
      f.precio.text = '\$ 120.000';
      final p = f.aPrenda(base: const Prenda(id: 'x', nombre: 'Jean', tipo: 'inferior', vecesUsada: 7));
      expect(p.precio, 120000);
      expect(p.vecesUsada, 7);
      expect(p.id, 'x');
      f.dispose();
    });

    test('Outfit ida y vuelta con Firestore', () {
      const o = Outfit(nombre: 'Look', prendaIds: ['b', 'a'], ocasion: 'trabajo', calificacion: 4, origen: 'ia');
      final leido = Outfit.desdeFirestore('id', o.aFirestore());
      expect(leido.prendaIds, ['b', 'a']);
      expect(leido.calificacion, 4);
      expect(leido.origen, 'ia');
      expect(leido.clave, 'a|b');
      expect(Outfit.desdeFirestore('z', {'calificacion': 99, 'origen': 'raro'}).calificacion, 5);
    });

    test('PlanDia usa la fecha AAAA-MM-DD como id', () {
      expect(PlanDia.claveDe(DateTime(2026, 3, 7)), '2026-03-07');
      final plan = PlanDia.desdeFirestore('2026-03-07', {'outfitNombre': 'Look', 'prendaIds': ['a', 1]});
      expect(plan.dia, DateTime(2026, 3, 7));
      expect(plan.prendaIds, ['a']);
    });

    test('Coleccion lee sus prendas', () {
      final c = Coleccion.desdeFirestore('c', {'nombre': ' Oficina ', 'prendaIds': ['a', 'b']});
      expect(c.nombre, 'Oficina');
      expect(c.aFirestore()['prendaIds'], ['a', 'b']);
    });
  });
}
