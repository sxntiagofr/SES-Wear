// Repositorios en memoria para probar pantallas sin Firebase.
import 'dart:async';
import 'dart:typed_data';

import 'package:ses_wear/features/collections/data/colecciones_repositorio.dart';
import 'package:ses_wear/features/collections/models/coleccion.dart';
import 'package:ses_wear/features/outfits/data/outfits_repositorio.dart';
import 'package:ses_wear/features/outfits/models/outfit.dart';
import 'package:ses_wear/features/planner/data/planificador_repositorio.dart';
import 'package:ses_wear/features/planner/models/plan_dia.dart';
import 'package:ses_wear/features/wardrobe/data/prendas_repositorio.dart';
import 'package:ses_wear/features/wardrobe/models/prenda.dart';

import '../auditoria/fakes.dart';

/// Valor observable: emite el valor actual al suscribirse y cada cambio.
class Vivo<T> {
  Vivo(this._valor);
  T _valor;
  final _cambios = StreamController<T>.broadcast();

  T get valor => _valor;
  set valor(T v) {
    _valor = v;
    _cambios.add(v);
  }

  Stream<T> get stream async* {
    yield _valor;
    yield* _cambios.stream;
  }
}

class PrendasFalso extends PrendasRepositorio {
  PrendasFalso(List<Prenda> prendas)
      : datos = Vivo(prendas),
        super(functions: FakeFunctions(), firestore: FakeFirestore(), storage: FakeStorage(), auth: FakeAuth());

  final Vivo<List<Prenda>> datos;
  final usos = <String>[];

  @override
  Stream<List<Prenda>> observar() => datos.stream;

  @override
  Future<void> registrarUso(Iterable<String> prendaIds) async => usos.addAll(prendaIds);

  @override
  Future<void> actualizar(Prenda prenda) async =>
      datos.valor = [for (final p in datos.valor) p.id == prenda.id ? prenda : p];

  @override
  Future<void> eliminar(Prenda prenda) async => datos.valor = datos.valor.where((p) => p.id != prenda.id).toList();

  @override
  Future<Prenda> guardar(Prenda prenda, Uint8List foto, {String tipo = 'image/jpeg'}) async {
    final nueva = prenda.copyWith(id: 'n${datos.valor.length}');
    datos.valor = [nueva, ...datos.valor];
    return nueva;
  }
}

class OutfitsFalso extends OutfitsRepositorio {
  OutfitsFalso([List<Outfit> iniciales = const [], this.respuestaIA = const []])
      : datos = Vivo(iniciales),
        super(firestore: FakeFirestore(), ia: IAFalsa(), auth: FakeAuth());

  final Vivo<List<Outfit>> datos;
  final List<Outfit> respuestaIA;
  final pedidosIA = <({String ocasion, String clima, Set<String> prendaIds})>[];

  @override
  Stream<List<Outfit>> observar() => datos.stream;

  @override
  Future<Outfit> guardar(Outfit outfit) async {
    final nuevo = outfit.copyWith(id: 'o${datos.valor.length}');
    datos.valor = [nuevo, ...datos.valor];
    return nuevo;
  }

  void _cambiar(String id, Outfit Function(Outfit) f) =>
      datos.valor = [for (final o in datos.valor) o.id == id ? f(o) : o];

  @override
  Future<void> marcarFavorito(String id, bool favorito) async => _cambiar(id, (o) => o.copyWith(favorito: favorito));

  @override
  Future<void> calificar(String id, int estrellas) async => _cambiar(id, (o) => o.copyWith(calificacion: estrellas));

  @override
  Future<void> eliminar(String id) async => datos.valor = datos.valor.where((o) => o.id != id).toList();

  @override
  Future<List<Outfit>> generarConIA({
    required List<Prenda> prendas,
    required String ocasion,
    String clima = 'cualquiera',
    int cantidad = 3,
    List<List<String>> excluir = const [],
  }) async {
    pedidosIA.add((ocasion: ocasion, clima: clima, prendaIds: {for (final p in prendas) p.id!}));
    return respuestaIA;
  }
}

class PlanFalso extends PlanificadorRepositorio {
  PlanFalso([Map<String, PlanDia> iniciales = const {}])
      : datos = Vivo({...iniciales}),
        super(firestore: FakeFirestore(), auth: FakeAuth());

  final Vivo<Map<String, PlanDia>> datos;

  @override
  Stream<Map<String, PlanDia>> observar({DateTime? desde}) => datos.stream;

  @override
  Future<void> asignar(PlanDia plan) async => datos.valor = {...datos.valor, plan.fecha: plan};

  @override
  Future<void> quitar(String fecha) async => datos.valor = {...datos.valor}..remove(fecha);
}

class ColeccionesFalso extends ColeccionesRepositorio {
  ColeccionesFalso([List<Coleccion> iniciales = const []])
      : datos = Vivo(iniciales),
        super(firestore: FakeFirestore(), auth: FakeAuth());

  final Vivo<List<Coleccion>> datos;

  @override
  Stream<List<Coleccion>> observar() => datos.stream;

  @override
  Future<Coleccion> crear(String nombre, {String descripcion = ''}) async {
    final c = Coleccion(id: 'c${datos.valor.length}', nombre: nombre, descripcion: descripcion);
    datos.valor = [...datos.valor, c];
    return c;
  }

  @override
  Future<void> actualizar(Coleccion coleccion) async =>
      datos.valor = [for (final c in datos.valor) c.id == coleccion.id ? coleccion : c];

  @override
  Future<void> eliminar(String id) async => datos.valor = datos.valor.where((c) => c.id != id).toList();
}

/// Armario básico para las pruebas: alcanza para armar outfits.
const armarioDePrueba = [
  Prenda(id: 's1', nombre: 'Camisa blanca', tipo: 'superior', colorPrimario: 'blanco', formalidad: 'semiformal'),
  Prenda(id: 's2', nombre: 'Camiseta negra', tipo: 'superior', colorPrimario: 'negro'),
  Prenda(id: 'i1', nombre: 'Jean azul', tipo: 'inferior', colorPrimario: 'azul', vecesUsada: 6, precio: 120000),
  Prenda(id: 'c1', nombre: 'Tenis blancos', tipo: 'calzado', colorPrimario: 'blanco', vecesUsada: 2),
];
