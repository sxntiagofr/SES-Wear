import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repositorio.dart';
import '../models/perfil_usuario.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

/// Decide qué ver al abrir la app:
/// - Sin sesión → Iniciar sesión.
/// - Con sesión pero sin autorización de datos (primera vez con Google o
///   Facebook) → pantalla para aceptarla.
/// - Con sesión y autorización → la app (`app`).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.app, this.repositorio});

  final Widget app;
  final AuthRepositorio? repositorio;

  @override
  Widget build(BuildContext context) {
    final repo = repositorio ?? AuthRepositorio.instancia;
    return StreamBuilder<User?>(
      stream: repo.cambiosDeSesion(),
      builder: (context, sesion) {
        if (sesion.connectionState == ConnectionState.waiting) return const _Cargando();
        final usuario = sesion.data;
        // Las sesiones anónimas de versiones anteriores no cuentan como cuenta.
        if (usuario == null || usuario.isAnonymous) return LoginScreen(repositorio: repositorio);

        return StreamBuilder<PerfilUsuario?>(
          key: ValueKey(usuario.uid),
          stream: repo.observarPerfil(usuario.uid),
          builder: (context, perfil) {
            if (perfil.hasError) {
              return _ErrorPerfil(repo: repo, detalle: '${perfil.error}');
            }
            // El perfil se crea justo después de registrarse o del primer
            // inicio con Google/Facebook; mientras llega, se espera.
            if (!perfil.hasData) return _Cargando(repo: repo);
            final datos = perfil.data!;
            if (!datos.consentimiento.vigente) {
              return _ConsentimientoScreen(repo: repo, perfil: datos);
            }
            return app;
          },
        );
      },
    );
  }
}

class _Cargando extends StatefulWidget {
  const _Cargando({this.repo});

  final AuthRepositorio? repo;

  @override
  State<_Cargando> createState() => _CargandoState();
}

class _CargandoState extends State<_Cargando> {
  bool _demorado = false;

  @override
  void initState() {
    super.initState();
    if (widget.repo != null) {
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) setState(() => _demorado = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            if (_demorado) ...[
              const SizedBox(height: 24),
              const Text(
                'Esto está tardando más de lo normal.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              TextButton(onPressed: widget.repo!.cerrarSesion, child: const Text('Cerrar sesión')),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorPerfil extends StatelessWidget {
  const _ErrorPerfil({required this.repo, required this.detalle});

  final AuthRepositorio repo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    debugPrint('No se pudo leer el perfil: $detalle');
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'No pudimos cargar tu perfil. Revisa tu conexión e inténtalo de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: repo.cerrarSesion, child: const Text('Cerrar sesión')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Autorización de tratamiento de datos para cuentas nuevas de Google o Facebook.
class _ConsentimientoScreen extends StatefulWidget {
  const _ConsentimientoScreen({required this.repo, required this.perfil});

  final AuthRepositorio repo;
  final PerfilUsuario perfil;

  @override
  State<_ConsentimientoScreen> createState() => _ConsentimientoScreenState();
}

class _ConsentimientoScreenState extends State<_ConsentimientoScreen> {
  bool _cargando = false;

  Future<void> _aceptar() async {
    setState(() => _cargando = true);
    try {
      await widget.repo.aceptarConsentimiento(widget.perfil.uid);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.', error: true);
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.perfil.nombreCorto;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.privacy_tip_outlined, size: 56, color: AppTheme.link),
                  const SizedBox(height: 20),
                  Text(
                    nombre.isEmpty ? '¡Bienvenido a SES Wear!' : '¡Hola, $nombre!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Antes de empezar necesitamos tu autorización para tratar tus datos personales y las fotos de tus prendas, según la Ley 1581 de 2012.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => mostrarPoliticaDatos(context),
                    child: const Text('Leer la autorización completa'),
                  ),
                  const SizedBox(height: 16),
                  BotonPrincipal(texto: 'Acepto y continuar', cargando: _cargando, onPressed: _aceptar),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _cargando ? null : widget.repo.cerrarSesion,
                    style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                    child: const Text('No acepto, salir'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
