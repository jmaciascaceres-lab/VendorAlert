# VendorAlert

Addon para **World of Warcraft: Forever** que te ayuda a llegar preparado a las mazmorras.
Te avisa con un sonido cuando pasas cerca de un vendedor y tus bolsas están casi llenas o tu equipo está dañado, y además vende la chatarra y repara por ti.

## Funciones

- **Alerta de vendedor cercano**: suena un aviso cuando ves a un vendedor conocido y tus bolsas superan el 80% (configurable).
- **Aprende vendedores solo**: cada vendedor queda registrado la primera vez que abres su ventana, incluyendo si puede reparar.
- **Vende objetos grises** automáticamente al abrir un vendedor y muestra el oro obtenido.
- **Repara automáticamente** si el vendedor repara y tienes oro suficiente.
- **Aviso de durabilidad baja** cuando alguna pieza de tu equipo baja del 30% (configurable).
- **Sonido personalizable**: usa tu propio archivo de audio.

Las bolsas especiales (carcajes, munición, almas) no cuentan para el porcentaje.

## Instalación

1. Descarga la última versión desde [CurseForge](#) o desde la sección *Releases* de este repositorio.
2. Descomprime la carpeta `VendorAlert` en:
   ```
   World of Warcraft\_forever_\Interface\AddOns\
   ```
3. Reinicia el juego y comprueba que VendorAlert esté activado en la lista de AddOns.

## Comandos

| Comando | Qué hace |
|---|---|
| `/va` | Muestra el estado actual y la lista de comandos |
| `/va umbral 80` | Porcentaje de bolsas llenas para la alerta |
| `/va durabilidad 30` | Porcentaje de durabilidad para el aviso |
| `/va vender` | Activa o desactiva la venta de grises |
| `/va reparar` | Activa o desactiva la reparación automática |
| `/va sonido` | Activa o desactiva todos los sonidos |
| `/va tono` | Alterna entre tu sonido personalizado y el aviso de banda |
| `/va test` | Reproduce una alerta de prueba |
| `/va reset` | Borra la lista de vendedores aprendidos |

## Sonido personalizado

1. Pon tu archivo en `VendorAlert\Sounds\` con el nombre `alerta.mp3` o `alerta.ogg` (OGG Vorbis; WoW no reproduce `.wav` ni OGG Opus).
2. Reinicia el juego por completo (`/reload` no detecta archivos nuevos).
3. Prueba con `/va test`.

Si no hay archivo, se usa el sonido de aviso de banda del juego.

## Consejos

- Activa las placas de nombre de aliados (**Mayús+V**) para detectar vendedores a distancia.
- Los vendedores aprendidos se guardan por cuenta en `WTF\Account\<CUENTA>\SavedVariables\VendorAlert.lua`, así que todos tus personajes los comparten.

## Errores y sugerencias

Abre un *Issue* en este repositorio. Si es un error de Lua, activa `/console scriptErrors 1` y copia el mensaje completo.

## Licencia

[MIT](LICENSE)

---

### English

VendorAlert plays a sound when you are near a known vendor and your bags are almost full (or your gear needs repair), and automatically sells grey items and repairs. Type `/va` in game for the command list.
