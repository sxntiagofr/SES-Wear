import '../../wardrobe/models/prenda.dart';

/// Estadísticas y consumo responsable (RF-06), calculadas en el celular a
/// partir de las prendas del armario.
class Estadisticas {
  Estadisticas._({
    required this.totalPrendas,
    required this.totalUsos,
    required this.masUsadas,
    required this.enDesuso,
    required this.costoPorUso,
    required this.paleta,
    required this.porcentajeEnUso,
  });

  /// Una prenda está "en desuso" si no se ha usado en [diasDesuso] días
  /// (o nunca, si se registró hace más de [diasGracia] días).
  factory Estadisticas.calcular(
    List<Prenda> prendas, {
    DateTime? hoy,
    int diasDesuso = 60,
    int diasGracia = 30,
    int top = 5,
  }) {
    final ahora = hoy ?? DateTime.now();

    bool desuso(Prenda p) {
      if (p.ultimoUso != null) return ahora.difference(p.ultimoUso!).inDays >= diasDesuso;
      if (p.vecesUsada > 0) return false; // se usó pero no sabemos cuándo
      return p.fechaCreacion == null || ahora.difference(p.fechaCreacion!).inDays >= diasGracia;
    }

    final usadas = prendas.where((p) => p.vecesUsada > 0).toList()
      ..sort((a, b) => b.vecesUsada.compareTo(a.vecesUsada));

    final olvidadas = prendas.where(desuso).toList()
      ..sort((a, b) {
        final fa = a.ultimoUso ?? a.fechaCreacion ?? DateTime(2000);
        final fb = b.ultimoUso ?? b.fechaCreacion ?? DateTime(2000);
        return fa.compareTo(fb);
      });

    final conCosto = prendas.where((p) => p.precio != null).toList()
      ..sort((a, b) => (b.costoPorUso ?? b.precio!).compareTo(a.costoPorUso ?? a.precio!));

    final conteo = <String, int>{};
    for (final p in prendas) {
      final c = p.colorPrimario.trim().toLowerCase();
      if (c.isNotEmpty) conteo[c] = (conteo[c] ?? 0) + 1;
    }
    final paleta = conteo.entries.toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));

    return Estadisticas._(
      totalPrendas: prendas.length,
      totalUsos: prendas.fold(0, (s, p) => s + p.vecesUsada),
      masUsadas: usadas.take(top).toList(),
      enDesuso: olvidadas,
      costoPorUso: conCosto,
      paleta: [for (final e in paleta) (color: e.key, cantidad: e.value)],
      porcentajeEnUso: prendas.isEmpty ? 0 : (prendas.length - olvidadas.length) / prendas.length,
    );
  }

  final int totalPrendas;
  final int totalUsos;
  final List<Prenda> masUsadas;
  final List<Prenda> enDesuso;

  /// Prendas con precio, de la que más cuesta por uso a la que menos.
  final List<Prenda> costoPorUso;

  /// Colores principales del armario, del más frecuente al menos.
  final List<({String color, int cantidad})> paleta;

  /// Fracción (0 a 1) de prendas que NO están en desuso.
  final double porcentajeEnUso;
}
