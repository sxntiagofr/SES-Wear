import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repositorio.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

/// Pantalla «Crear cuenta» (Figma: figma_crear_cuenta).
///
/// Crea la cuenta en Firebase Authentication y guarda nombre, apellido,
/// teléfono, correo y la autorización de datos en `users/{uid}`.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key, this.repositorio});

  final AuthRepositorio? repositorio;

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _aceptaDatos = false;
  bool _mostrarErrorDatos = false;
  bool _cargando = false;

  AuthRepositorio get _repo => widget.repositorio ?? AuthRepositorio.instancia;

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _telefono, _correo, _contrasena]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    final ok = await ejecutarAccionAuth(context, accion);
    if (!mounted) return;
    setState(() => _cargando = false);
    // La sesión ya está abierta: se vuelve a la raíz, donde AuthGate muestra la app.
    if (ok) Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  }

  void _registrarme() {
    final formularioOk = _formKey.currentState!.validate();
    setState(() => _mostrarErrorDatos = !_aceptaDatos);
    if (!formularioOk || !_aceptaDatos) return;
    _ejecutar(
      () => _repo.registrar(
        nombre: _nombre.text,
        apellido: _apellido.text,
        telefono: _telefono.text,
        email: _correo.text,
        contrasena: _contrasena.text,
        aceptaDatos: _aceptaDatos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leadingWidth: 68,
        leading: Center(
          child: IconButton.filledTonal(
            tooltip: 'Volver',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.textPrimary,
              fixedSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: const Text('Crear cuenta'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampoAuth(
                        controller: _nombre,
                        hint: 'Nombre',
                        icono: Icons.person_outline,
                        capitalizacion: TextCapitalization.words,
                        autofill: const [AutofillHints.givenName],
                        validator: Validar.requerido('nombre'),
                      ),
                      const SizedBox(height: 14),
                      CampoAuth(
                        controller: _apellido,
                        hint: 'Apellido',
                        icono: Icons.how_to_reg_outlined,
                        capitalizacion: TextCapitalization.words,
                        autofill: const [AutofillHints.familyName],
                        validator: Validar.requerido('apellido'),
                      ),
                      const SizedBox(height: 14),
                      CampoAuth(
                        controller: _telefono,
                        hint: 'Número de teléfono',
                        icono: Icons.phone_outlined,
                        teclado: TextInputType.phone,
                        autofill: const [AutofillHints.telephoneNumber],
                        validator: Validar.telefono,
                      ),
                      const SizedBox(height: 14),
                      CampoAuth(
                        controller: _correo,
                        hint: 'Correo electrónico',
                        icono: Icons.mail_outline,
                        teclado: TextInputType.emailAddress,
                        autofill: const [AutofillHints.email],
                        validator: Validar.correo,
                      ),
                      const SizedBox(height: 14),
                      CampoAuth(
                        controller: _contrasena,
                        hint: 'Contraseña',
                        icono: Icons.lock_outline,
                        esContrasena: true,
                        accion: TextInputAction.done,
                        autofill: const [AutofillHints.newPassword],
                        validator: Validar.contrasenaNueva,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                        child: Text(
                          'Mínimo 8 caracteres, con letras y números.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CasillaDatos(
                        valor: _aceptaDatos,
                        mostrarError: _mostrarErrorDatos,
                        onChanged: (v) => setState(() {
                          _aceptaDatos = v;
                          if (v) _mostrarErrorDatos = false;
                        }),
                      ),
                      const SizedBox(height: 24),
                      BotonPrincipal(
                        texto: 'Registrarme',
                        cargando: _cargando,
                        onPressed: _registrarme,
                      ),
                      const SizedBox(height: 20),
                      EnlaceInferior(
                        pregunta: '¿Ya tienes cuenta?',
                        accion: 'Inicia sesión',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Casilla obligatoria de autorización de tratamiento de datos (Ley 1581 de 2012).
class _CasillaDatos extends StatelessWidget {
  const _CasillaDatos({required this.valor, required this.mostrarError, required this.onChanged});

  final bool valor;
  final bool mostrarError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: valor, onChanged: (v) => onChanged(v ?? false)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
                    children: [
                      const TextSpan(text: 'Acepto la '),
                      TextSpan(
                        text: 'autorización de tratamiento de datos personales',
                        style: TextStyle(color: AppTheme.link, fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()..onTap = () => mostrarPoliticaDatos(context),
                      ),
                      const TextSpan(text: ' (Ley 1581 de 2012).'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (mostrarError)
          Padding(
            padding: EdgeInsets.only(left: 14),
            child: Text(
              'Debes aceptar la autorización para crear la cuenta.',
              style: TextStyle(fontSize: 12, color: AppTheme.error),
            ),
          ),
      ],
    );
  }
}
