import 'package:material_ui/material_ui.dart';

/// Convierte el nombre de un color en español (como lo escribe la IA) en un
/// color para mostrarlo en pantalla. Si no lo conoce, devuelve gris.
Color colorDeNombre(String nombre) {
  final n = nombre.trim().toLowerCase();
  const tabla = <String, Color>{
    'negro': Color(0xFF111111),
    'blanco': Color(0xFFF7F7F7),
    'hueso': Color(0xFFEDE6D6),
    'crema': Color(0xFFF3E7C9),
    'beige': Color(0xFFD9C3A0),
    'nude': Color(0xFFE3BC9A),
    'gris': Color(0xFF8A8A8A),
    'gris claro': Color(0xFFC4C4C4),
    'gris oscuro': Color(0xFF4A4A4A),
    'café': Color(0xFF6B4226),
    'marrón': Color(0xFF6B4226),
    'camel': Color(0xFFC19A6B),
    'caqui': Color(0xFFBDB07A),
    'azul': Color(0xFF2E5AAC),
    'azul claro': Color(0xFF8DB8E8),
    'azul oscuro': Color(0xFF1B2A4A),
    'azul marino': Color(0xFF14213D),
    'denim': Color(0xFF3B5B83),
    'celeste': Color(0xFF8DCFF0),
    'turquesa': Color(0xFF30C5C0),
    'verde': Color(0xFF2E8B57),
    'verde oliva': Color(0xFF708238),
    'verde militar': Color(0xFF4B5320),
    'amarillo': Color(0xFFF2C94C),
    'mostaza': Color(0xFFD4A017),
    'naranja': Color(0xFFF2994A),
    'rojo': Color(0xFFD32F2F),
    'vinotinto': Color(0xFF6D1A2A),
    'rosado': Color(0xFFF4A6C1),
    'rosa': Color(0xFFF4A6C1),
    'fucsia': Color(0xFFD6338A),
    'morado': Color(0xFF7B3FA0),
    'lila': Color(0xFFB9A3E3),
    'dorado': Color(0xFFD4AF37),
    'plateado': Color(0xFFC0C0C0),
  };
  return tabla[n] ?? tabla[n.split(' ').first] ?? const Color(0xFF9E9E9E);
}
