import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/boton_degradado.dart';
import '../assistant/screens/chat_screen.dart';
import '../wardrobe/data/prendas_repositorio.dart';
import '../wardrobe/models/prenda.dart';
import '../wardrobe/screens/armario_screen.dart';
import '../wardrobe/screens/camara_screen.dart';
import '../wardrobe/screens/detalle_prenda_screen.dart';
import '../wardrobe/widgets/tarjeta_prenda.dart';

/// Pestañas de la navegación principal (ver main.dart). La cámara del centro
/// es una acción, no una pestaña.
class Pestanas {
  Pestanas._();
  static const inicio = 0;
  static const crear = 1;
  static const calendario = 2;
  static const perfil = 3;
}

/// Inicio (diseño de referencia): logo, "Añadir Prenda", categorías,
/// acceso al asistente y un vistazo al armario.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.prendasRepositorio, this.abrirAsistente});

  final PrendasRepositorio? prendasRepositorio;

  /// Para pruebas: qué hacer al tocar el asistente (por defecto abre el chat).
  final VoidCallback? abrirAsistente;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _prendasRepo = widget.prendasRepositorio ?? PrendasRepositorio();
  late final Stream<List<Prenda>> _prendas = _prendasRepo.observar();

  static const _categorias = [
    (emoji: '👕', titulo: 'Partes de arriba', tipo: 'superior'),
    (emoji: '👖', titulo: 'Partes de abajo', tipo: 'inferior'),
    (emoji: '👟', titulo: 'Calzado', tipo: 'calzado'),
    (emoji: '👜', titulo: 'Accesorios', tipo: 'accesorio'),
  ];

  void _abrir(Widget pantalla) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  void _armario([String? tipo]) => _abrir(ArmarioScreen(repositorio: _prendasRepo, tipoInicial: tipo));

  void _asistente() => widget.abrirAsistente != null ? widget.abrirAsistente!() : _abrir(const ChatScreen());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _encabezado(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BotonDegradado(
                  texto: 'Añadir Prenda',
                  icono: Icons.photo_camera_outlined,
                  alto: 56,
                  tamanoTexto: 19,
                  onPressed: () => agregarPrenda(context, repositorio: _prendasRepo),
                ),
                const SizedBox(height: 26),
                const _Titulo('Categorías'),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in _categorias)
                      Expanded(
                        child: _Categoria(emoji: c.emoji, titulo: c.titulo, onTap: () => _armario(c.tipo)),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                _TarjetaAsistente(onTap: _asistente),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: _Titulo('Mi Armario')),
                    IconButton(
                      tooltip: 'Ver todo el armario',
                      onPressed: _armario,
                      icon: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<Prenda>>(
                  stream: _prendas,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text('No se pudo cargar tu armario.', style: TextStyle(color: AppTheme.textSecondary));
                    }
                    if (!snap.hasData) {
                      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                    }
                    final prendas = snap.data!;
                    if (prendas.isEmpty) {
                      return _ArmarioVacio(onAgregar: () => agregarPrenda(context, repositorio: _prendasRepo));
                    }
                    final visibles = prendas.take(9).toList();
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibles.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemBuilder: (_, i) => TarjetaPrenda(
                        prenda: visibles[i],
                        conNombre: false,
                        onTap: () => _abrir(DetallePrendaScreen(prenda: visibles[i], repositorio: _prendasRepo)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.degradadoEncabezado),
      padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 8, 12, 20),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              tooltip: 'Asistente de estilo',
              onPressed: _asistente,
              icon: Icon(Icons.auto_awesome, color: AppTheme.textPrimary),
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/logo.png',
                height: 132,
                semanticLabel: 'SES Wear. Tu estilo, más inteligente',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary));
}

class _Categoria extends StatelessWidget {
  const _Categoria({required this.emoji, required this.titulo, required this.onTap});

  final String emoji;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: titulo,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(height: 6),
              Text(
                titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: 12, height: 1.15, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaAsistente extends StatelessWidget {
  const _TarjetaAsistente({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(gradient: AppTheme.degradado, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pregúntale a tu asistente',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('¿Qué me pongo hoy con lo que tengo?',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArmarioVacio extends StatelessWidget {
  const _ArmarioVacio({required this.onAgregar});
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(Icons.checkroom_outlined, size: 40, color: AppTheme.primary),
          const SizedBox(height: 8),
          Text(
            'Tu armario está vacío. Toma la foto de tu primera prenda y la IA la registra por ti.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          TextButton(onPressed: onAgregar, child: const Text('Tomar foto')),
        ],
      ),
    );
  }
}
