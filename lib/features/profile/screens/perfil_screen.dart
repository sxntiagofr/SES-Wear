import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/controlador_tema.dart';
import '../../auth/data/auth_repositorio.dart';
import '../../auth/models/perfil_usuario.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../assistant/screens/chat_screen.dart';
import '../../collections/screens/colecciones_screen.dart';
import '../../stats/screens/estadisticas_screen.dart';
import '../../wardrobe/data/prendas_repositorio.dart';
import '../../wardrobe/screens/armario_screen.dart';
import 'editar_perfil_screen.dart';

/// Pestaña Perfil: datos de la cuenta, editar, eliminar la cuenta (Ley 1581)
/// y cerrar sesión.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key, this.repositorio, this.controladorTema, this.prendasRepositorio});

  final AuthRepositorio? repositorio;

  /// Para pruebas; por defecto, el de toda la app.
  final ControladorTema? controladorTema;

  /// Repositorio compartido del armario (para los accesos de abajo).
  final PrendasRepositorio? prendasRepositorio;

  Future<void> _cerrarSesion(BuildContext context, AuthRepositorio repo) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres salir de tu cuenta en este celular?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
        ],
      ),
    );
    if (salir == true) await repo.cerrarSesion();
  }

  Future<void> _eliminarCuenta(BuildContext context, AuthRepositorio repo) async {
    final confirmado = await showDialog<bool>(context: context, builder: (_) => const _DialogoEliminarCuenta());
    if (confirmado != true || !context.mounted) return;

    // Se guarda el navegador raíz: al borrar la cuenta, AuthGate quita esta
    // pantalla y el diálogo de progreso hay que cerrarlo igual.
    final navegador = Navigator.of(context, rootNavigator: true);
    final mensajero = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Eliminando tu cuenta y tus datos…')),
          ],
        ),
      ),
    );
    String? error;
    try {
      await repo.eliminarCuenta();
      // AuthGate detecta que ya no hay sesión y muestra Iniciar sesión.
    } on ErrorAuth catch (e) {
      error = e.mensaje;
    } catch (_) {
      error = 'No se pudo eliminar la cuenta. Revisa tu conexión.';
    }
    navegador.pop();
    mensajero.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Tu cuenta y todos tus datos fueron eliminados.'),
        backgroundColor: error == null ? null : AppTheme.fondoError,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = repositorio ?? AuthRepositorio.instancia;
    final usuario = repo.usuarioActual;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: usuario == null
          ? const SizedBox.shrink()
          : StreamBuilder<PerfilUsuario?>(
              stream: repo.observarPerfil(usuario.uid),
              builder: (context, snap) {
                final perfil = snap.data;
                final pref = perfil?.preferencias;
                final gustos = [...?pref?.estilos, ...?pref?.colores];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _Encabezado(usuario: usuario, perfil: perfil),
                    const SizedBox(height: 24),
                    _Dato(icono: Icons.mail_outline, titulo: 'Correo', valor: perfil?.email ?? usuario.email ?? ''),
                    _Dato(icono: Icons.phone_outlined, titulo: 'Teléfono', valor: perfil?.telefono ?? ''),
                    _Dato(icono: Icons.location_city_outlined, titulo: 'Ciudad', valor: perfil?.ciudad ?? ''),
                    _Dato(icono: Icons.palette_outlined, titulo: 'Preferencias de estilo', valor: gustos.join(', ')),
                    _Dato(
                      icono: Icons.login,
                      titulo: 'Método de acceso',
                      valor: switch (perfil?.proveedor) {
                        'google.com' => 'Google',
                        'facebook.com' => 'Facebook',
                        _ => 'Correo y contraseña',
                      },
                    ),
                    _Accesos(prendasRepositorio: prendasRepositorio),
                    _SelectorTema(controlador: controladorTema ?? ControladorTema.instancia),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: perfil == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EditarPerfilScreen(perfil: perfil, repositorio: repo),
                              ),
                            ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar perfil'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radioBoton)),
                      ),
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: const Text('Autorización de datos personales'),
                      onPressed: () => mostrarPoliticaDatos(context),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(color: AppTheme.border),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radioBoton)),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                      onPressed: () => _cerrarSesion(context, repo),
                    ),
                    const SizedBox(height: 28),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Eliminar mi cuenta y mis datos'),
                      onPressed: () => _eliminarCuenta(context, repo),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

/// Pide escribir ELIMINAR para confirmar, porque no se puede deshacer.
class _DialogoEliminarCuenta extends StatefulWidget {
  const _DialogoEliminarCuenta();

  @override
  State<_DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<_DialogoEliminarCuenta> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listo = _texto.text.trim().toUpperCase() == 'ELIMINAR';
    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se borrarán para siempre tu cuenta, tu perfil, tus prendas y sus fotos, tus outfits, '
            'tu calendario, tus colecciones y tus conversaciones con el asistente. No se puede deshacer.',
          ),
          const SizedBox(height: 16),
          const Text('Escribe ELIMINAR para confirmar:'),
          TextField(
            controller: _texto,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          onPressed: listo ? () => Navigator.pop(context, true) : null,
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.usuario, required this.perfil});

  final User usuario;
  final PerfilUsuario? perfil;

  @override
  Widget build(BuildContext context) {
    final nombre = perfil?.nombreCompleto.isNotEmpty == true
        ? perfil!.nombreCompleto
        : (usuario.displayName ?? perfil?.nombreCorto ?? '');
    final foto = perfil?.fotoUrl ?? usuario.photoURL;
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: AppTheme.primaryLight,
          foregroundImage: foto != null ? NetworkImage(foto) : null,
          child: Text(
            nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.link),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre.isEmpty ? 'Tu cuenta' : nombre,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              if (perfil?.rol == 'admin')
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Administrador', style: TextStyle(color: AppTheme.accent)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.titulo, required this.valor});

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radioCampo),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppTheme.textSecondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  valor.isEmpty ? 'Sin registrar' : valor,
                  style: TextStyle(color: valor.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modo claro, oscuro o según el celular (RNF-02).
class _SelectorTema extends StatelessWidget {
  const _SelectorTema({required this.controlador});

  final ControladorTema controlador;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apariencia', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ValueListenableBuilder<ModoTema>(
            valueListenable: controlador,
            builder: (context, modo, _) => SizedBox(
              width: double.infinity,
              child: SegmentedButton<ModoTema>(
                showSelectedIcon: false,
                segments: [
                  for (final m in ModoTema.values)
                    ButtonSegment(
                      value: m,
                      label: Text(m == ModoTema.sistema ? 'Automático' : m.etiqueta),
                      icon: Icon(switch (m) {
                        ModoTema.sistema => Icons.brightness_auto_outlined,
                        ModoTema.claro => Icons.light_mode_outlined,
                        ModoTema.oscuro => Icons.dark_mode_outlined,
                      }),
                    ),
                ],
                selected: {modo},
                onSelectionChanged: (s) => controlador.cambiar(s.first),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Accesos a las secciones que no tienen pestaña propia.
class _Accesos extends StatelessWidget {
  const _Accesos({required this.prendasRepositorio});

  final PrendasRepositorio? prendasRepositorio;

  @override
  Widget build(BuildContext context) {
    // El repositorio se crea al tocar, no al dibujar la pantalla.
    PrendasRepositorio repo() => prendasRepositorio ?? PrendasRepositorio();
    void abrir(Widget pantalla) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    final accesos = [
      (Icons.checkroom_outlined, 'Mi armario', () => abrir(ArmarioScreen(repositorio: repo()))),
      (Icons.collections_bookmark_outlined, 'Colecciones', () => abrir(ColeccionesScreen(prendasRepositorio: repo()))),
      (Icons.bar_chart_rounded, 'Estadísticas', () => abrir(EstadisticasScreen(prendasRepositorio: repo()))),
      (Icons.auto_awesome, 'Asistente de estilo', () => abrir(const ChatScreen())),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 6),
      child: Material(
        color: AppTheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radioCampo),
          side: BorderSide(color: AppTheme.border),
        ),
        child: Column(
          children: [
            for (final (icono, titulo, accion) in accesos)
              ListTile(
                leading: Icon(icono, color: AppTheme.link),
                title: Text(titulo, style: TextStyle(color: AppTheme.textPrimary)),
                trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: accion,
              ),
          ],
        ),
      ),
    );
  }
}
