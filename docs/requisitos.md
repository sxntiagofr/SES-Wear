# Requerimientos

Fuente: documento de la entrega del segundo corte (`docs/entregas/`).

## Requerimientos funcionales

| ID | Nombre | Descripción | Módulo |
|---|---|---|---|
| RF-01 | Registro e identificación automática por IA | Captura de prendas con la cámara o desde la galería; remoción automática del fondo; etiquetado automático de color, tipo de prenda, categoría y tela. Inicio de sesión, registro y recuperación de contraseña. | `auth`, `wardrobe` |
| RF-02 | Gestión del armario virtual (CRUD) | Crear, ver, editar y eliminar prendas. Búsqueda con filtros por color, estación, formalidad y tipo de prenda. | `wardrobe` |
| RF-03 | Generador inteligente de outfits | Combinaciones a partir del inventario del usuario, filtradas por ocasión (casual, trabajo, deportivo, fiesta). Guardar favoritos, calificar y pedir alternativas. | `outfits` |
| RF-04 | Asistente conversacional de moda | Chatbot de IA para preguntas sobre combinaciones, tendencias e ideas, con asesoría según la imagen que el usuario quiere proyectar. | `assistant` |
| RF-05 | Etiquetas y colecciones personalizadas | Etiquetas y colecciones creadas por el usuario (p. ej. "Ropa de oficina") y generación de combinaciones dentro de ellas. | `collections` |
| RF-06 | Estadísticas y consumo responsable | Prendas más usadas y en desuso, costo por uso y paleta de colores predominante. | `stats` |
| RF-07 | Planificador de atuendos | Programar qué vestir en días futuros con vista de calendario. | `planner` |

## Requerimientos no funcionales

| ID | Nombre | Criterio |
|---|---|---|
| RNF-01 | Rendimiento | Procesamiento de imagen por IA ≤ 3 s por foto; sugerencia de outfits < 1 s. |
| RNF-02 | Usabilidad | Diseño mobile-first en Figma, uso con una mano, máximo 3 toques a cualquier función principal, modo claro y oscuro. |
| RNF-03 | Idioma e internacionalización | Localización `es-CO` (ISO 639-1 / ISO 3166-1), léxico colombiano de prendas (saco, buso, jean), escalable a otras regiones cambiando solo la capa de traducción. |
| RNF-04 | Disponibilidad y escalabilidad | 99.9 % de disponibilidad; backend escalable horizontalmente. |
| RNF-05 | Seguridad y privacidad | HTTPS/TLS en tránsito, datos y fotos cifrados en reposo, cumplimiento de la normativa de protección de datos personales. |
| RNF-06 | Multiplataforma | Flutter (Dart) para Android 8.0+ e iOS 14.0+. |
