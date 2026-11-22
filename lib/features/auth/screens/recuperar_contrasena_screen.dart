import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repositorio.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

/// Pantalla «Restaurar contraseña» (Figma: figma_restaurar_contrasena).
///
/// Firebase envía un correo con un enlace para crear una contraseña nueva.
class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({super.key, this.correoInicial = '', this.repositorio});

  final String correoInicial;
  final AuthRepositorio? repositorio;

  @override
  State<RecuperarContrasenaScreen> createState() => _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _correo = TextEditingController(text: widget.correoInicial);
  bool _cargando = false;
  String? _enviadoA;

  AuthRepositorio get _repo => widget.repositorio ?? AuthRepositorio.instancia;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    final correo = _correo.text.trim();
    final ok = await ejecutarAccionAuth(context, () => _repo.recuperarContrasena(correo));
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (ok) _enviadoA = correo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textPrimary),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Volver'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: SizedBox(width: 200, child: LogoSesWear(alto: 220))),
                    const SizedBox(height: 28),
                    const Text(
                      'Restaurar contraseña',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ingresa tu correo electrónico y te enviaremos instrucciones para crear una nueva contraseña.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    CampoAuth(
                      controller: _correo,
                      hint: 'Correo electrónico',
                      icono: Icons.mail_outline,
                      teclado: TextInputType.emailAddress,
                      accion: TextInputAction.send,
                      autofill: const [AutofillHints.email],
                      validator: Validar.correo,
                      onSubmitted: (_) => _enviar(),
                    ),
                    const SizedBox(height: 22),
                    BotonPrincipal(
                      texto: _enviadoA == null ? 'Enviar instrucciones' : 'Enviar de nuevo',
                      cargando: _cargando,
                      onPressed: _enviar,
                    ),
                    const SizedBox(height: 20),
                    if (_enviadoA != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mark_email_read_outlined, color: AppTheme.success),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Si $_enviadoA tiene una cuenta, te llegará un correo con el enlace en unos minutos.',
                                style: const TextStyle(color: AppTheme.textPrimary, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Revisa también tu carpeta de correo no deseado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
