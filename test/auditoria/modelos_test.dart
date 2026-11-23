// Auditoría de los modelos (lectura robusta de Firestore) y validaciones.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/features/assistant/models/mensaje.dart';
import 'package:ses_wear/features/auth/models/perfil_usuario.dart';
import 'package:ses_wear/features/auth/widgets/auth_widgets.dart';
import 'package:ses_wear/features/wardrobe/models/prenda.dart';

void main() {
  group('Prenda.desdeFirestore', () {
    test('lee un documento normal', () {
      final p = Prenda.desdeFirestore('p1', {
        'nombre': ' Buso gris ',
        'tipo': 'abrigo',
        'formalidad': 'casual',
        'estacion': 'frío',
        'vecesUsada': 3,
        'fechaCreacion': Timestamp.fromDate(DateTime(2026, 11, 1)),
      });
      expect(p.id, 'p1');
      expect(p.nombre, 'Buso gris');
      expect(p.estacion, 'frío');
      expect(p.vecesUsada, 3);
      expect(p.fechaCreacion, DateTime(2026, 11, 1));
    });

    test('valores fuera de las listas cerradas se corrigen', () {
      final p = Prenda.desdeFirestore('p2', {'nombre': 'x', 'tipo': 'zapato', 'estacion': 'otoño'});
      expect(p.tipo, 'superior');
      expect(p.estacion, 'todo el año');
    });

    // Las reglas ya validan los tipos, pero un documento antiguo o escrito desde
    // la consola puede venir mal formado; no debe romper TODO el armario.
    test('Regresión: fotoUrl con tipo incorrecto no debería lanzar excepción', () {
      expect(() => Prenda.desdeFirestore('p3', {'nombre': 'x', 'fotoUrl': 123}), returnsNormally);
    });

    test('Regresión: vecesUsada guardado como texto no debería lanzar excepción', () {
      expect(() => Prenda.desdeFirestore('p4', {'nombre': 'x', 'vecesUsada': '2'}), returnsNormally);
    });
  });

  group('Mensaje', () {
    test('rol desconocido se trata como asistente y lee la fecha', () {
      final m = Mensaje.desdeFirestore({
        'rol': 'sistema',
        'texto': 'hola',
        'fecha': Timestamp.fromDate(DateTime(2026, 1, 2)),
      });
      expect(m.esDelUsuario, isFalse);
      expect(m.fecha, DateTime(2026, 1, 2));
    });
  });

  group('PerfilUsuario', () {
    test('consentimiento de una versión anterior ya no es vigente', () {
      final p = PerfilUsuario.desdeFirestore('u', {
        'consentimientoDatos': {'aceptado': true, 'version': '0.9'},
      });
      expect(p.consentimiento.vigente, isFalse);
    });

    test('nombreCorto toma el primer nombre aunque haya espacios dobles', () {
      final p = PerfilUsuario.desdeFirestore('u', {'nombre': 'Ana  María'});
      expect(p.nombreCorto, 'Ana');
    });

    test('lee las preferencias ignorando valores que no son texto', () {
      final p = PerfilUsuario.desdeFirestore('u', {
        'preferencias': {
          'estilos': ['urbano', 3, null],
          'colores': 'negro',
        },
      });
      expect(p.preferencias.estilos, ['urbano']);
      expect(p.preferencias.colores, isEmpty);
    });
  });

  group('Validaciones de formularios', () {
    test('correo con letras y tildes en la contraseña', () {
      expect(Validar.contrasenaNueva('camión2026'), isNull);
    });

    test('Regresión: el correo rechaza dominios con puntos dobles (ana@correo..com)', () {
      expect(Validar.correo('ana@correo..com'), isNotNull);
    });
  });
}
