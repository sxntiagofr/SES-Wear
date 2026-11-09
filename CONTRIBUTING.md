# Guía de contribución

## División del trabajo

Cada integrante tiene su área, su rama principal de trabajo y sus carpetas. Así evitamos tocar los mismos archivos al mismo tiempo y los conflictos al hacer merge.

| Integrante | Área | Rama de trabajo | Carpetas que le corresponden |
|---|---|---|---|
| **Santiago Martinez** | Arquitectura, interfaz visual y base de datos (Firebase / Firestore) | `feature/arquitectura` | `lib/core/`, `lib/features/` (excepto `assistant/`), `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `pubspec.yaml`, `android/`, `ios/` |
| **Sofia Salazar Castro** | Chatbot e inteligencia artificial (asistente de moda, identificación de prendas) | `feature/chatbot` | `lib/features/assistant/`, servicios de IA |
| **Edison Moreno** | Documentación (requisitos, diagramas, manuales, entregas) | `docs/documentacion` | `docs/`, `README.md` |

Si necesitas cambiar algo fuera de tus carpetas (por ejemplo, agregar una dependencia en `pubspec.yaml` para el chatbot), avísale primero al responsable de esa parte.

## Ramas

```
main                      ← versión estable, la que se entrega
 └── develop              ← integración del trabajo de todo el equipo
      ├── feature/arquitectura   (Santiago)
      ├── feature/chatbot        (Sofia)
      └── docs/documentacion     (Edison)
```

| Rama | Uso |
|---|---|
| `main` | Versión estable para las entregas. **Nadie trabaja ni hace commit aquí.** Solo recibe merges desde `develop`. |
| `develop` | Rama de trabajo del equipo. Todas las ramas nacen de aquí y todos los pull requests van hacia aquí. |
| `feature/<nombre>` | Una funcionalidad. Además de las ramas de arriba, se pueden crear ramas más pequeñas, p. ej. `feature/registro-prendas`, `feature/chatbot-historial`. |
| `fix/<nombre>` | Corrección de un error, p. ej. `fix/login-contrasena`. |
| `docs/<nombre>` | Cambios solo de documentación. |

### ¿A qué rama envío mis cambios?

| Lo que hiciste | Rama de origen | Pull request hacia |
|---|---|---|
| Pantallas, navegación, modelos, Firebase, reglas | `feature/arquitectura` (o `feature/<algo>` de Santiago) | `develop` |
| Chatbot, IA, reconocimiento de prendas | `feature/chatbot` (o `feature/<algo>` de Sofia) | `develop` |
| Documentos, diagramas, manuales | `docs/documentacion` | `develop` |
| Corrección de un error | `fix/<nombre>` | `develop` |
| Preparar una entrega | `develop` | `main` |

**Nunca** se abre un pull request de una rama `feature/`, `fix/` o `docs/` directamente hacia `main`.

## Flujo de trabajo con GitHub Desktop

### Primera vez

1. Acepta la invitación al repositorio que te llega por correo desde GitHub.
2. En GitHub Desktop: **File → Clone repository** → pestaña **GitHub.com** → `sxntiagofr/SES-Wear` → **Clone**.
   _Si ya tienes la carpeta en tu PC: **File → Add local repository** y eliges la carpeta `ses-wear`._
3. Arriba, en **Current branch**, cámbiate a `develop`.
4. Si tu rama ya existe en GitHub, selecciónala en **Current branch**. Si no existe: **Current branch → New branch**, escribe el nombre (p. ej. `feature/chatbot`), en **Create branch based on** elige `develop` y luego **Publish branch**.

### Cada vez que trabajes

1. Cámbiate a tu rama en **Current branch**.
2. **Fetch origin** y, si aparece, **Pull origin**, para traer lo último.
3. Trae lo nuevo de `develop` a tu rama: **Branch → Update from develop**.
4. Trabaja en tus archivos.
5. Abajo a la izquierda escribe el mensaje del commit (ver formato abajo) → **Commit to `<tu-rama>`**.
6. **Push origin**.
7. **Branch → Create pull request**. En GitHub verifica que diga **base: `develop`** ← **compare: `<tu-rama>`**, llena la plantilla y crea el PR.
8. Otro integrante lo revisa y, si está bien, hace **Merge** hacia `develop`.

### Lo mismo desde la terminal

```bash
git checkout develop
git pull
git checkout -b feature/mi-funcionalidad      # o: git checkout feature/chatbot
git merge develop                              # traer lo nuevo de develop a tu rama
# ... trabajar ...
git add .
git commit -m "feat: descripción corta"
git push -u origin feature/mi-funcionalidad
gh pr create --base develop
```

## Mensajes de commit

Formato: `tipo(área): descripción corta en minúscula`

| Tipo | Cuándo |
|---|---|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de un error |
| `docs` | Documentación |
| `style` | Formato, sin cambios de lógica |
| `refactor` | Reorganización de código sin cambiar comportamiento |
| `test` | Pruebas |
| `chore` | Configuración, dependencias, tareas varias |

El `(área)` es opcional y ayuda a saber de quién es el cambio: `arquitectura`, `ui`, `firebase`, `chatbot`, `ia`, `docs`.

Ejemplos:

```
feat(ui): pantalla principal con navegación inferior
feat(firebase): guardar prendas en Firestore
feat(chatbot): pantalla de conversación con el asistente
feat(ia): extracción del color principal de la prenda
docs: diagrama de casos de uso actualizado
fix(firebase): reglas de seguridad para la colección outfits
```

Haz commits pequeños y frecuentes, con un cambio claro cada uno, en lugar de un solo commit enorme al final.

## Pull requests

- Siempre hacia `develop`, salvo la entrega (`develop` → `main`).
- Llena la plantilla: qué cambia, qué requerimiento (RF) cubre y cómo se probó.
- Al menos otro integrante lo revisa antes de hacer merge.
- No hagas merge de tu propio PR sin revisión.

Antes de abrirlo, si ya existe código Flutter:

```bash
flutter analyze
flutter test
dart format .
```

## Entregas (develop → main)

Cuando `develop` esté estable para una entrega, se abre un pull request de `develop` hacia `main`. Después del merge, se puede marcar la versión con una etiqueta, p. ej. `entrega-final`.

## Secretos

No subir al repositorio claves privadas, cuentas de servicio de Firebase (`serviceAccountKey.json`), archivos `.env` ni API keys de servicios de IA. El `.gitignore` ya los excluye. Las claves de la IA nunca van dentro de la app: deben quedar del lado del servidor (p. ej. Cloud Functions).
