import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repositorio.dart';
import '../../auth/models/perfil_usuario.dart';

/// Pestaña Perfil (versión inicial): datos de la cuenta y cerrar sesión.
/// Editar datos, preferencias y eliminar la cuenta van en la siguiente iteración.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key, this.repositorio});

  final AuthRepositorio? repositorio;

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
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _Encabezado(usuario: usuario, perfil: perfil),
                    const SizedBox(height: 24),
                    _Dato(icono: Icons.mail_outline, titulo: 'Correo', valor: perfil?.email ?? usuario.email ?? ''),
                    _Dato(icono: Icons.phone_outlined, titulo: 'Teléfono', valor: perfil?.telefono ?? ''),
                    _Dato(icono: Icons.location_city_outlined, titulo: 'Ciudad', valor: perfil?.ciudad ?? ''),
                    _Dato(
                      icono: Icons.login,
                      titulo: 'Método de acceso',
                      valor: switch (perfil?.proveedor) {
                        'google.com' => 'Google',
                        'facebook.com' => 'Facebook',
                        _ => 'Correo y contraseña',
                      },
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.border),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radioBoton)),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                      onPressed: () async {
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
                      },
                    ),
                  ],
                );
              },
            ),
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
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.link),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre.isEmpty ? 'Tu cuenta' : nombre,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              if (perfil?.rol == 'admin')
                const Padding(
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
                Text(titulo, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
