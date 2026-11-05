# TriageU

App iOS para estudiantes universitarios que ayuda a **priorizar actividades académicas** (parciales, tareas, proyectos, exposiciones) según la materia, la fecha de entrega, el peso en la nota, el nivel de preparación y el tiempo estimado.

Microproyecto de **Desarrollo de Aplicaciones Móviles** (Electiva) · Universidad del Cauca · SwiftUI.

**Integrantes:** Aurelio José Muñoz Rios · Isabella Plaza Díaz · Isabella Perez Hoyos

---

## Capturas de pantalla

| Hoy | Mi ruta | Progreso |
|:---:|:---:|:---:|
| ![Hoy](docs/screenshots/01-hoy.png) | ![Mi ruta](docs/screenshots/02-mi-ruta.png) | ![Progreso](docs/screenshots/03-progreso.png) |
| Resumen, búsqueda, filtros, vista lista/calendario y tarjetas de actividad | Línea de tiempo de próximas entregas | Avance semanal de actividades completadas |

| Nueva actividad | Perfil |
|:---:|:---:|
| ![Nueva actividad](docs/screenshots/04-nueva-actividad.png) | ![Perfil](docs/screenshots/05-perfil.png) |
| Formulario con materia, tipo, fecha, hora opcional, peso, preparación y horas estimadas | Cuenta, materias editables y recordatorios |

Además existe la pantalla **Acerca de** (descripción de la app, tecnologías y créditos), accesible desde Perfil.

---

## Funcionalidades

- Registro, **edición y borrado** de actividades (con *deshacer* durante 5 s).
- **Prioridad automática** (ALTA / MEDIA / BAJA) calculada con la preparación y el peso en la nota.
- **Búsqueda y filtros** por materia, prioridad y estado; orden por fecha, prioridad o recientes.
- **Vista calendario** mensual con carga de horas por día y aviso de sobrecarga.
- **Materias editables** con color propio.
- **Hora de entrega opcional** por actividad.
- **Notificaciones locales** de recordatorio (horas configurables en Perfil).
- **Autenticación** con correo y contraseña (Supabase Auth) y recuperación de contraseña.
- **Sincronización en la nube** (Supabase) con resolución de conflictos por última escritura.
- **Modo sin conexión**: los cambios se encolan y se envían al volver la red.
- **Widget** de pantalla de inicio con las próximas entregas.

---

## Arquitectura

Patrón **MVVM** con persistencia local y servicios de red separados por módulos.

```
TriageU/TriageU/
├── TriageUApp.swift          Punto de entrada, ModelContainer y orquestación de sincronización
├── ContentView.swift         Navegación (barra inferior) y pantallas principales
├── Model/                    Entidades SwiftData: TriageActivity, Subject
├── ViewModel/                TriageViewModel (@Observable): formulario y cálculo de prioridad
├── View/                     AuthView, EditActivityView, SubjectsView, ActivityCalendarView, SetupView
└── Services/
    ├── SupabaseService.swift     Red: cliente REST (URLSession + Codable) y sincronización
    ├── SyncQueue.swift           Cola persistente de cambios pendientes (modo offline)
    ├── AuthManager.swift         Sesión de usuario (Supabase Auth), token en Keychain
    ├── Keychain.swift            Almacenamiento seguro de la sesión
    ├── NotificationService.swift Recordatorios locales
    └── WidgetBridge.swift        Datos compartidos con el widget (App Group)
TriageUWidget/                Extensión WidgetKit
```

| Capa | Implementación |
|---|---|
| **Vista** | SwiftUI (`@State`, `@Binding`, `@Bindable`, `@Environment`, `@Query`) |
| **ViewModel** | `TriageViewModel` con `@Observable`: estado del formulario, validación y prioridad |
| **Persistencia** | **SwiftData** (`TriageActivity`, `Subject`) como base de datos local |
| **Red** | **API REST de Supabase** (PostgREST + Auth) con `URLSession` y `Codable` |
| **Sincronización** | `SyncQueue` + `SupabaseService.sync`: *last-write-wins* por `updated_at` |

### Flujo de datos

1. El usuario crea o edita una actividad → se guarda en **SwiftData** (la app funciona sin red).
2. El cambio se encola en `SyncQueue` y se envía a Supabase en cuanto hay conexión.
3. Al abrir la app se descarga el estado remoto y se mezcla con el local.
4. Se reprograman las notificaciones y se actualiza el widget.

---

## Puesta en marcha

Requisitos: Xcode 26+, iOS 26.2+.

1. Abre `TriageU/TriageU.xcodeproj`.
2. (Opcional, para la nube) Crea un proyecto en [Supabase](https://supabase.com), ejecuta `TriageU/supabase_schema.sql` en el SQL Editor y habilita Authentication → Email.
3. Pon tu URL y *anon key* en `TriageU/TriageU/Services/SupabaseConfig.swift`. Sin credenciales la app funciona solo en local, sin login.
4. Para el widget, selecciona tu equipo de firma en los targets `TriageU` y `TriageUWidget` y habilita la capacidad **App Groups** (`group.edu.unicauca.aplimovil.TriageU`).
5. Ejecuta el esquema `TriageU` en un simulador o dispositivo.

---

## Cumplimiento del enunciado (Taller 2)

| Requisito | Estado | Dónde |
|---|---|---|
| ≥ 5 pantallas + Acerca de / créditos | Cumple | Hoy, Mi ruta, Nueva actividad, Progreso, Perfil, Acerca de (+ login y edición) |
| Navegación entre pantallas | Cumple | Barra inferior personalizada, hojas modales y pantalla Acerca de |
| Entradas de usuario | Cumple | `TextField`, `Toggle`, `Stepper`, `DatePicker`, `Menu` |
| Gestión de estado | Cumple | `@State`, `@Binding`, `@Bindable`, `@Environment`, `@Observable` |
| Almacenamiento local | Cumple | SwiftData |
| Red / API en línea | Cumple | Supabase (REST + Auth) |
| Arquitectura ViewModel + Red + Persistencia | Cumple | Carpetas `ViewModel/`, `Services/`, `Model/` |
| Repositorio público, una rama por integrante | Revisar | Ramas `aurelio`, `Isabella`; verificar que todos tengan commits |
| Diagrama de arquitectura a mano | Pendiente | Entregable del informe |
| Reflexión SwiftUI vs Jetpack Compose | Pendiente | Entregable del informe |

### Funcionalidades adicionales (puntos extra)

Autenticación con Supabase Auth, sincronización con resolución de conflictos, cola de cambios sin conexión, notificaciones locales, widget con App Group, vista calendario y materias personalizables.
