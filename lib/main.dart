import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/controlador_tema.dart';
import 'core/widgets/barra_navegacion.dart';
import 'features/auth/screens/auth_gate.dart';
import 'features/home/home_screen.dart';
import 'features/outfits/data/outfits_repositorio.dart';
import 'features/outfits/screens/crear_outfit_screen.dart';
import 'features/outfits/screens/mis_outfits_screen.dart';
import 'features/planner/data/planificador_repositorio.dart';
import 'features/profile/screens/perfil_screen.dart';
import 'features/wardrobe/data/prendas_repositorio.dart';
import 'features/wardrobe/screens/camara_screen.dart';
import 'firebase_options.dart';

/// `flutter run --dart-define=USAR_EMULADORES=true` usa los emuladores locales
/// de Firebase (firebase emulators:start) en vez del proyecto real.
const _usarEmuladores = bool.fromEnvironment('USAR_EMULADORES');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_usarEmuladores) {
    await _conectarEmuladores();
  } else {
    await _activarAppCheck();
  }
  await ControladorTema.instancia.cargar();
  runApp(const SESWearApp());
}

/// Puertos de firebase.json. El emulador de Android ve el computador en 10.0.2.2.
Future<void> _conectarEmuladores() async {
  final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  debugPrint('SES Wear usando los emuladores de Firebase en $host');
}

/// App Check certifica que las llamadas a Firebase vienen de la app oficial
/// (Play Integrity en Android, App Attest en iOS). En modo debug usa el
/// proveedor de depuración: el token aparece en la consola y se registra en
/// Firebase Console → App Check. Ver docs/despliegue.md.
Future<void> _activarAppCheck() async {
  final movil = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (!movil) return;
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode ? const AndroidPlayIntegrityProvider() : const AndroidDebugProvider(),
      providerApple: kReleaseMode ? const AppleAppAttestProvider() : const AppleDebugProvider(),
    );
  } catch (e) {
    // Sin App Check la app sigue funcionando mientras el servidor no lo exija.
    debugPrint('No se pudo activar App Check: $e');
  }
}

class SESWearApp extends StatelessWidget {
  const SESWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AplicarTema(
      controlador: ControladorTema.instancia,
      builder: (context, tema) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SES Wear',
        theme: tema,
        // Sin sesión muestra Iniciar sesión; con sesión, la app.
        home: const AuthGate(app: MainNavigation()),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _actual = Pestanas.inicio;

  // Un solo repositorio de cada tipo para toda la sesión.
  final _prendas = PrendasRepositorio();
  final _outfits = OutfitsRepositorio();
  final _planificador = PlanificadorRepositorio();

  late final List<Widget> _pantallas = [
    HomeScreen(prendasRepositorio: _prendas),
    CrearOutfitScreen(
      prendasRepositorio: _prendas,
      outfitsRepositorio: _outfits,
      planificadorRepositorio: _planificador,
    ),
    MisOutfitsScreen(
      prendasRepositorio: _prendas,
      outfitsRepositorio: _outfits,
      planificadorRepositorio: _planificador,
    ),
    PerfilScreen(prendasRepositorio: _prendas),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _actual, children: _pantallas),
      bottomNavigationBar: BarraNavegacion(
        actual: _actual,
        alElegir: (i) => setState(() => _actual = i),
        alCamara: () => agregarPrenda(context, repositorio: _prendas),
      ),
    );
  }
}
