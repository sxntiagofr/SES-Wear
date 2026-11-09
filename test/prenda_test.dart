import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/features/wardrobe/models/prenda.dart';

void main() {
  test('Prenda.desdeIA llena los campos y corrige valores fuera de las opciones', () {
    final prenda = Prenda.desdeIA({
      'esPrenda': true,
      'nombre': 'Jean azul clásico',
      'tipo': 'inferior',
      'categoria': 'jean',
      'colorPrimario': 'azul',
      'tela': 'denim',
      'estilo': 'clásico',
      'formalidad': 'muy formal', // no está en la lista → casual
      'estacion': 'todo el año',
      'etiquetas': ['tiro alto', '', 'bota recta'],
    });

    expect(prenda.nombre, 'Jean azul clásico');
    expect(prenda.tipo, 'inferior');
    expect(prenda.formalidad, 'casual');
    expect(prenda.etiquetas, ['tiro alto', 'bota recta']);
    expect(prenda.identificadaPorIA, isTrue);
    expect(prenda.aFirestore()['tela'], 'denim');
  });
}
