import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/colores.dart';
import '../../../core/widgets/miniatura_prenda.dart';
import '../../wardrobe/data/prendas_repositorio.dart';
import '../../wardrobe/models/prenda.dart';
import '../../wardrobe/widgets/campos_prenda.dart';
import '../logic/estadisticas.dart';

/// Estadísticas y consumo responsable (RF-06): prendas más usadas y en
/// desuso, costo por uso y paleta de colores predominante.
class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key, this.prendasRepositorio});

  final PrendasRepositorio? prendasRepositorio;

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  late final Stream<List<Prenda>> _prendas = (widget.prendasRepositorio ?? PrendasRepositorio()).observar();

  static String pesos(double v) =>
      '\$${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: StreamBuilder<List<Prenda>>(
        stream: _prendas,
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('No se pudieron cargar tus prendas.'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final e = Estadisticas.calcular(snap.data!);
          if (e.totalPrendas == 0) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Registra prendas en tu armario para ver tus estadísticas.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _Cifra(titulo: 'Prendas', valor: '${e.totalPrendas}')),
                  const SizedBox(width: 12),
                  Expanded(child: _Cifra(titulo: 'Usos registrados', valor: '${e.totalUsos}')),
                  const SizedBox(width: 12),
                  Expanded(child: _Cifra(titulo: 'En uso', valor: '${(e.porcentajeEnUso * 100).round()} %')),
                ],
              ),
              _Seccion(
                titulo: 'Las que más usas',
                vacio: 'Marca "La usé hoy" en tus prendas u outfits para ver cuáles usas más.',
                hijos: [
                  for (final p in e.masUsadas)
                    _FilaPrenda(prenda: p, detalle: '${p.vecesUsada} ${p.vecesUsada == 1 ? 'uso' : 'usos'}'),
                ],
              ),
              _Seccion(
                titulo: 'En desuso',
                subtitulo: 'Sin usar en los últimos 60 días. Dales una oportunidad antes de comprar algo nuevo.',
                vacio: '¡Muy bien! Estás usando todo tu armario.',
                hijos: [
                  for (final p in e.enDesuso.take(10))
                    _FilaPrenda(
                      prenda: p,
                      detalle: p.ultimoUso == null
                          ? 'Nunca usada'
                          : 'Último uso: ${p.ultimoUso!.day}/${p.ultimoUso!.month}/${p.ultimoUso!.year}',
                    ),
                ],
              ),
              _Seccion(
                titulo: 'Costo por uso',
                subtitulo: 'Precio ÷ veces usada. Entre más la uses, más rinde lo que pagaste.',
                vacio: 'Agrega el precio de tus prendas (Editar prenda) para calcular su costo por uso.',
                hijos: [
                  for (final p in e.costoPorUso.take(10))
                    _FilaPrenda(
                      prenda: p,
                      detalle: p.costoPorUso == null
                          ? '${pesos(p.precio!)} · aún sin usar'
                          : '${pesos(p.costoPorUso!)} por uso',
                    ),
                ],
              ),
              _Seccion(
                titulo: 'Tu paleta de colores',
                vacio: 'Tus prendas aún no tienen color registrado.',
                hijos: [
                  for (final c in e.paleta.take(8))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: colorDeNombre(c.color)),
                      title: Text(CamposPrenda.capitalizar(c.color)),
                      trailing: Text('${(c.cantidad * 100 / e.totalPrendas).round()} %'),
                      subtitle: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: c.cantidad / e.totalPrendas,
                          color: colorDeNombre(c.color),
                          backgroundColor: AppTheme.border,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(titulo, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.hijos, required this.vacio, this.subtitulo});

  final String titulo;
  final String? subtitulo;
  final String vacio;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (subtitulo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitulo!, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ),
          const SizedBox(height: 8),
          if (hijos.isEmpty) Text(vacio, style: TextStyle(color: AppTheme.textSecondary)) else ...hijos,
        ],
      ),
    );
  }
}

class _FilaPrenda extends StatelessWidget {
  const _FilaPrenda({required this.prenda, required this.detalle});

  final Prenda prenda;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: MiniaturaPrenda(prenda: prenda, tamano: 44),
      title: Text(prenda.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(detalle),
    );
  }
}
