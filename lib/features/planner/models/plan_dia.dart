/// Lo que el usuario planeó ponerse un día (RF-07).
/// Vive en `users/{uid}/planificador/{AAAA-MM-DD}`.
class PlanDia {
  const PlanDia({required this.fecha, this.outfitId, this.outfitNombre = '', this.prendaIds = const [], this.nota = ''});

  /// Día en formato AAAA-MM-DD (también es el id del documento).
  final String fecha;
  final String? outfitId;
  final String outfitNombre;

  /// Copia de las prendas del outfit, por si luego se borra el outfit.
  final List<String> prendaIds;
  final String nota;

  static String claveDe(DateTime dia) =>
      '${dia.year.toString().padLeft(4, '0')}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';

  DateTime get dia => DateTime.parse(fecha);

  factory PlanDia.desdeFirestore(String id, Map<String, dynamic> datos) => PlanDia(
        fecha: id,
        outfitId: datos['outfitId'] is String ? datos['outfitId'] as String : null,
        outfitNombre: datos['outfitNombre'] is String ? datos['outfitNombre'] as String : '',
        prendaIds: datos['prendaIds'] is List ? (datos['prendaIds'] as List).whereType<String>().toList() : const [],
        nota: datos['nota'] is String ? datos['nota'] as String : '',
      );

  Map<String, dynamic> aFirestore() => {
        'fecha': fecha,
        'outfitId': outfitId,
        'outfitNombre': outfitNombre,
        'prendaIds': prendaIds,
        'nota': nota,
      };
}
