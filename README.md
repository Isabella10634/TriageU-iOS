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

| Nueva actividad | Perfil | Acerca de |
|:---:|:---:|:---:|
| ![Nueva actividad](docs/screenshots/04-nueva-actividad.png) | ![Perfil](docs/screenshots/05-perfil.png) | ![Acerca de](docs/screenshots/06-acerca-de.png) |
| Formulario con materia, tipo, fecha, hora opcional, peso, preparación y horas estimadas | Cuenta, materias editables y recordatorios | Descripción de la app, tecnologías y créditos (se abre desde Perfil) |

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

### Diagrama de capas

```mermaid
flowchart TB
    subgraph UI["Vista (SwiftUI)"]
        V1[TodayView]
        V2[RouteView]
        V3[TriageProgressView]
        V4[NewActivityView]
        V5[ProfileView]
        V6[AboutView]
        V7[AuthView / EditActivityView / SubjectsView]
    end

    VM["TriageViewModel<br/>(@Observable)"]

    subgraph Local["Persistencia local"]
        SD[(SwiftData<br/>TriageActivity · Subject)]
        KC[(Keychain<br/>sesión)]
    end

    subgraph Services["Servicios"]
        AUTH[AuthManager]
        SYNC[SupabaseService]
        Q[SyncQueue]
        NOTI[NotificationService]
        WB[WidgetBridge]
    end

    subgraph Remote["Nube"]
        SB[(Supabase<br/>Auth + PostgREST)]
    end

    W[Widget<br/>WidgetKit]

    UI --> VM
    UI -- "@Query" --> SD
    VM --> SD
    UI --> Q
    Q --> SYNC
    SYNC <--> SB
    AUTH <--> SB
    AUTH --> KC
    SYNC <--> SD
    UI --> NOTI
    SD --> WB
    WB -- "App Group" --> W
```

### Navegación entre pantallas

```mermaid
flowchart LR
    Start([Inicio]) --> Cfg{¿Supabase<br/>configurado?}
    Cfg -- No --> Tabs
    Cfg -- Sí --> Ses{¿Sesión<br/>activa?}
    Ses -- No --> Auth[AuthView<br/>login · registro · recuperar]
    Auth -- "inicia sesión" --> Tabs
    Ses -- Sí --> Tabs

    subgraph Tabs["Barra inferior"]
        Hoy[Hoy]
        Ruta[Mi ruta]
        Nueva["+ Nueva actividad"]
        Prog[Progreso]
        Perfil[Perfil]
    end

    Hoy -- "editar" --> Edit[/EditActivityView<br/>hoja/]
    Hoy -- "lista · calendario" --> Hoy
    Perfil --> About[Acerca de]
    Perfil -- "administrar" --> Subj[/SubjectsView<br/>hoja/]
    Perfil -- "cerrar sesión" --> Auth
```

### Modelo de datos

```mermaid
erDiagram
    USER ||--o{ ACTIVITY : "posee"
    USER ||--o{ SUBJECT : "posee"
    SUBJECT ||--o{ ACTIVITY : "agrupa (por nombre)"

    ACTIVITY {
        uuid id PK
        string title
        string subject
        string type
        date due_date
        bool has_due_time
        int weight_percent
        int preparation
        int duration_min
        string priority
        bool completed
        date created_at
        date updated_at
    }

    SUBJECT {
        uuid id PK
        string name
        string color_hex
        date created_at
        date updated_at
    }
```

### Sincronización (guardar una actividad)

```mermaid
sequenceDiagram
    actor U as Usuario
    participant V as Vista / ViewModel
    participant DB as SwiftData
    participant Q as SyncQueue
    participant S as Supabase

    U->>V: Guardar actividad
    V->>V: Calcula prioridad
    V->>DB: insert + save
    V->>Q: enqueue(upsert)
    V-->>U: Confirmación inmediata

    alt Hay conexión
        Q->>S: POST /activities (token del usuario)
        S-->>Q: 201
        Q->>Q: Quita el cambio de la cola
    else Sin conexión
        Q->>Q: Conserva el cambio en disco
        Note over Q: Reintenta al volver la red,<br/>al abrir la app y cada 30 s
    end
```

### Resolución de conflictos al sincronizar

```mermaid
flowchart TD
    A[Descargar estado remoto] --> B{¿Existe en ambos lados?}
    B -- "Solo remoto" --> C{¿Borrado pendiente<br/>en la cola?}
    C -- Sí --> C1[Ignorar]
    C -- No --> C2[Crear en local]
    B -- "Solo local" --> D{¿Ya estaba sincronizado?}
    D -- Sí --> D1[Se borró en otro dispositivo:<br/>eliminar en local]
    D -- No --> D2[Encolar subida]
    B -- "En ambos" --> E{Comparar updated_at}
    E -- "Remoto más nuevo" --> E1[Aplicar remoto en local]
    E -- "Local más nuevo" --> E2[Encolar subida]
    E -- "Igual (±1 s)" --> E3[Sin cambios]
```

### Flujo de datos

1. El usuario crea o edita una actividad → se guarda en **SwiftData** (la app funciona sin red).
2. El cambio se encola en `SyncQueue` y se envía a Supabase en cuanto hay conexión.
3. Al abrir la app se descarga el estado remoto y se mezcla con el local.
4. Se reprograman las notificaciones y se actualiza el widget.

---

