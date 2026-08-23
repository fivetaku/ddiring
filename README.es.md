[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | Español

# ddiring

<p align="center">
  <img src="assets/ddiring-hero-01.png" alt="ddiring" width="320">
</p>

> Notificaciones de finalización que de verdad te dicen **qué sesión** terminó.

¿Tienes 5–10 sesiones de Claude Code repartidas entre iTerm, Cursor y un gestor de sesiones? Un simple banner de "tarea completada" no sirve de nada: igual tienes que revisar ventana por ventana. ddiring ("띠링", el *¡ding!* coreano) hace que cada notificación responda tres preguntas de un vistazo: **qué carpeta de proyecto** (título), **en qué terminal o app** vive la sesión (subtítulo) y **qué le pediste** (cuerpo: un resumen de 70 caracteres de tu último prompt). En macOS con `terminal-notifier`, haz clic para saltar directo a esa app.

[Inicio rápido](#inicio-rápido) • [Por qué ddiring](#por-qué-ddiring) • [Cómo funciona](#cómo-funciona) • [Funciones](#funciones) • [Comandos](#comandos) • [Requisitos](#requisitos)

---

## Inicio rápido

### 1. Añade el marketplace

```
/plugin marketplace add https://github.com/fivetaku/gptaku_plugins.git
```

### 2. Instala

```
/plugin install ddiring
```

### 3. Reinicia Claude Code

(Los hooks y comandos solo se registran tras un reinicio.)

### 4. Úsalo

No hay nada que hacer: ahora cada sesión suena al terminar:

- **✅ my-app** / *iTerm* / "arregla el test de auth inestable y relanza CI" — terminado, en iTerm
- **⏸️ blog** / *Cursor* / "esperando permiso" — una sesión te necesita
- Haz clic en la notificación (macOS + `terminal-notifier`) para enfocar esa app

Opcional, para clic-y-enfocar:

```bash
brew install terminal-notifier
```

## Por qué ddiring

El trabajo multi-sesión tiene un micro-dolor recurrente: *algo* terminó, pero la notificación estándar no dice qué ni dónde. Los IDs de sesión tampoco ayudan: nadie asocia `a3f9c2` con "el refactor que lancé en Warp". ddiring muestra las tres cosas que sí reconoces: el nombre de la carpeta, el nombre de la app y tu propio último prompt.

## Cómo funciona

Un hook `Stop` se dispara cuando una sesión termina de responder (más un hook `Notification` para esperas de permiso/entrada, mostradas con ⏸️). El script:

1. lee la cola del transcript (primero 200KB, ampliando hasta 2MB si hace falta) para extraer tu último prompt **real** — omitiendo resultados de herramientas, etiquetas de sistema y marcas de interrupción;
2. identifica la app anfitriona por el entorno del proceso — `__CFBundleIdentifier` en macOS, sondeo de variables (`TERM_PROGRAM` → `WT_SESSION` → `ConEmuPID`, de dentro hacia fuera para esquivar falsos positivos por herencia) en Windows;
3. lanza la notificación: `terminal-notifier` (clicable) u `osascript` en macOS, un toast WinRT de PowerShell 5.1 en Windows.

Como los hooks ejecutan el script desde un archivo, los arreglos de mapeo se aplican **de inmediato a las sesiones ya abiertas** — sin reiniciar.

## Funciones

- **Más de 30 mapeos de apps, verificados con investigación** (`Info.plist` local, definiciones de cask de Homebrew, configs de repos oficiales): Terminal, iTerm2, VS Code (+Insiders), VSCodium, Cursor, Windsurf (Devin), Antigravity, Warp, Ghostty, Alacritty, kitty, WezTerm, Tabby, Hyper, Zed, JetBrains, Rio, Termius, Wave, Positron, Kiro, Trae, Xcode — más gestores de sesiones de Claude Code: Paseo, cmux, Conductor, Orca, Sculptor, Superset, Crystal, Waku, Jean, Fletch, Constellagent, GraphCode, Clave, Xum.
- **Paso directo de tmux/Zellij** — sin lógica de detección propia: se muestra la terminal anfitriona según las variables de entorno heredadas (un servidor tmux adjuntado luego desde otra app puede mostrar el anfitrión original).
- **Silencioso por defecto** — campanilla suave a volumen 0.2; silénciala o ajústala con variables de entorno.
- **Soporte de Windows (experimental)** — toast de PowerShell desde el hook de Git Bash. El toast en sí no necesita instalación extra, pero la extracción del prompt requiere Python 3 (sin él, mensaje genérico). Solo visual; aún sin verificar en hardware real — se agradecen reportes.
- **Apps desconocidas degradan con gracia** — se muestra `TERM_PROGRAM` o el bundle ID tal cual; añadir un mapeo es una línea.

## Comandos

| Comando | Qué hace |
|---|---|
| `/ddiring` | muestra el estado actual (config de entorno, presencia de `terminal-notifier`, terminal detectada) |
| `/ddiring test` | lanza una notificación de prueba con el transcript de esta sesión |
| `/ddiring volume 0.1` / `mute` | cambia el volumen / silencia |

### Configuración

Ponlo en el bloque `"env"` de tu archivo de ajustes de Claude (aplica a sesiones nuevas):

| Variable | Por defecto | Significado |
|---|---|---|
| `DDIRING_SILENT` | `0` | `1` = solo banner, sin sonido (macOS) |
| `DDIRING_VOLUME` | `0.2` | 0.0–1.0 (macOS) |
| `DDIRING_SOUND` | `Glass.aiff` | cualquier `/System/Library/Sounds/*.aiff` (macOS) |
| `DDIRING_HIDE_BODY` | `0` | `1` = ocultar el cuerpo (privacidad en pantalla de bloqueo / compartida) |

> Nota: el cuerpo de la notificación queda en el centro de notificaciones y la pantalla de bloqueo — usa `DDIRING_HIDE_BODY=1` si tus prompts son sensibles. La primera ejecución de `/ddiring` también instala el hook de avisos de actualización compartido de los plugins gptaku.

## Requisitos

- macOS (soporte completo) o Windows + Git Bash (experimental); en otros sistemas no hace nada silenciosamente
- `python3` (incluido en macOS) — para analizar el transcript
- Opcional: `terminal-notifier` para clic-y-enfocar (macOS)

## Licencia

[MIT](./LICENSE) — ver también [DISCLAIMER.md](./DISCLAIMER.md).
