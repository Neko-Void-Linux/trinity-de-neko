# TDE

Trinity Desktop Environment for VOID Linux. /// Trinity Desktop Environment para VOID Linux.
<br><p align="left">
  <img src="capturas_IGU/Captura de pantalla_2026-07-20_17-41-13.png" width="900">
</p>
<br><p align="left">
  <img src="capturas_IGU/Captura de pantalla_2026-07-20_17-25-10.png" width="900">
</p>Programa creado por Hugo Napoli. Contacto: hugonapoli@mailbox.org - https://t.me/entropiabinaria

# TDE para Void Linux

Script de compilación e instalación del **Trinity Desktop Environment** (TDE) en **Void Linux**, desde las fuentes oficiales.

**Entropía binaria** — https://codeberg.org/entropiabinaria/TDE

---

## Por qué existe esto

TDE está empaquetado oficialmente para Debian, Ubuntu, Arch, Gentoo, Slackware, Fedora, openSUSE, Mageia, FreeBSD, OpenBSD y derivados de OpenSolaris.
Para Void Linux, no.

El pedido está hecho: el [issue #19243 de void-packages](https://github.com/void-linux/void-packages/issues/19243) —"Package request: Trinity Desktop Environment"— fue abierto el **17 de febrero de 2020**. Sigue abierto, sin asignar, sin branches ni pull requests.
Este no es un problema exclusivo de Void: en el [issue equivalente de NixOS](https://github.com/NixOS/nixpkgs/issues/108967) un usuario lo resumió así: TDE es muy difícil de instalar en cualquier distribución no soportada. Y tiene toda la razón.
Este repositorio es un intento de resolver eso.

## Estado

**Experimental**

El script corrió completo y sin errores en dos máquinas físicas distintas (nada de virtuales), ambas Void Linux x86_64 con LightDM. El escritorio resultante es funcional y estable.

Lo que **no** está probado: la corrida completa con las funciones `compilar_idioma` e `instalar_menu` incorporadas. Ambas fueron validadas a mano, por separado, y funcionan; pero se agregaron al script después de las dos corridas exitosas. Si las probás, avisá.

## ¿Qué hace este programa?

Compila e instala la cadena mínima de TDE necesaria para un escritorio funcional:

```
tde-cmake -> tqt -> tqtinterface -> dbus-1-tqt -> tdelibs -> tdebase
```

También se agrega el módulo de traducciones al español, ya que TDE viene en inglés "por omisión".

Todo va a `/opt/trinity`, salvo `tqtinterface` que va a `/usr` (así lo indica el wiki oficial de TDE mientras la migración a CMake esté incompleta).

Al terminar, se hace que TDE aparezca como opción en la pantalla de "login" de LightDM, conviviendo con los escritorios o Window Managers que ya tengas instalados, sin tocarlos.

## Requisitos

- Void Linux.
- Conexión a Internet
- Un gestor de sesión gráfico (lo probé con LightDM porque lo uso, pero SDDM, LXDM, etc. pueden leer también `/usr/share/xsessions/`)
- Espera proporcional al hardware

## Ficha técnica

*Pendiente de medición rigurosa. Los valores actuales son aproximados o estimados.*

| Dato | Valor |
|---|---|
| Almacenamiento — instalación final | ~450 MB (`/opt/trinity` + `/etc/trinity` + archivos sueltos) |
| Almacenamiento — durante la compilación | *pendiente de medición* |
| Tiempo — AMD Ryzen 7 5800XT / 32 GB RAM | 10 minutos |
| Tiempo — hardware modesto | entre 50 y 60 minutos |
| RAM mínima recomendada | *pendiente de medición* |
| Versión de TDE | La última estable, detectada automáticamente |

## Uso

Descargá desde acá mismo este repositorio.

```
git clone https://codeberg.org/entropiabinaria/TDE.git
cd TDE
chmod +x trinity.sh
./trinity.sh
```

El script se auto-eleva con `sudo` si no lo corrés como root. Pide la contraseña una sola vez.
Cuando haya terminado, cerrá sesión y elegí **Trinity (TDE)** en la pantalla de "login".

## Configuración incluida

El directorio `entropia_conf/` contiene una configuración de escritorio que no es la que trae TDE por defecto. El script la aplica a todos los usuarios "humanos" del sistema (UID > 999), sin ser esto un capricho estético. TDE recién compilado vino así:

- Las ventanas minimizadas no aparecían en el panel (el applet del taskbar no está agregado).
- Los elementos del panel estaban desparramados sin criterio aparente: unos a la izquierda, otros al medio.
- Faltaban elementos básicos, como el reloj.
- El aspecto por defecto era un calco de Windows 2000. No es un problema de la interfaz en sí: es de dónde viene. No me gusta.

La configuración incluida arregla eso. **Todo lo que hay en ella es nativo de TDE**: no agregué ningún ícono externo, ni tema descargado, ni fondo de pantalla bajado de internet. No hay nada foráneo en todo esto.
Incluye idioma español y país Uruguay. Si no te sirve esta configuración, es solo tocar un archivo de texto: editá `entropia_conf/kdeglobals`.
Si preferís la configuración cruda de TDE, podés borrar el contenido de `entropia_conf/` antes de correr el script, pero para mí, no hay necesidad de ello.

## Configuración del script

Al principio de `trinity.sh` hay dos variables que podés cambiar:

- `idioma` — código del idioma de la interfaz (por defecto `es`). El repositorio `tde-i18n` pesa unos 3 GB completo; el script usa *sparse checkout* de git para bajar únicamente el idioma elegido.
- `prefijo` — dónde se instala TDE (por defecto `/opt/trinity`).

## Decisiones tomadas

- **Sin aRts.** El servidor de sonido de KDE 3 está desactivado (`-DWITH_ARTS=OFF`). TDE usa ALSA "directo"; si tenés PulseAudio, funciona por encima sin conflicto. 2 servidores de sonido peleándose por el "stream" de sonido, le sirve al usuario ni al sistema.
- **Con CUPS.** Los headers se instalan aunque no tengas el daemon corriendo. No arranca ningún servicio: deja TDE listo para cuando quieras imprimir.
- **Sin htdig.** El indexador del centro de ayuda no está empaquetado en Void y su última versión estable es de 2004.
- **Versión más reciente, siempre.** El script consulta la API de la Gitea oficial de TDE y compila la última versión estable publicada. No está clavado ni "hardcodeado" a un número.
- **Sin `-j` en `make`.** La compilación es secuencial. Es más lenta, pero cuando algo falla el error se lee. En un proyecto experimental eso vale enormemente más que la velocidad.

## Cómo revertir

El script imprime estas instrucciones al terminar:

```
rm -rf /opt/trinity
rm -f /etc/ld.so.conf.d/trinity.conf && ldconfig
rm -f /etc/profile.d/trinity.sh
rm -f /usr/share/xsessions/tde.desktop
rm -f /etc/xdg/menus/tde-applications.menu
```

Para los archivos que `tqtinterface` y `tde-cmake` instalan en `/usr`, el script guarda los manifiestos de CMake en `/opt/trinity/.registro/`. **Copiálos antes de borrar `/opt/trinity`** o los perdés.
Las dependencias de compilación instaladas con `xbps` quedan. Son "headers", y no interfieren con nada, salvo por el espacio que puedan ocupar, que no es grande. La lista completa está en la matriz `libs_devel` del script.

## De dónde salió cada cosa

Nada de esto se inventó. TDE no publica una lista de dependencias utilizable -la de la wiki oficial arrastra ebuilds de Gentoo de hace más de una década y los propios mantenedores piden que alguien la revise-, así que la información real hay que sacarla de los empaquetados de otras distribuciones:

- **[tde-packaging](https://mirror.git.trinitydesktop.org/gitea/TDE/tde-packaging)** — repositorio oficial de empaquetado de TDE. De ahí salió casi todo:
  - **Slackware** (`Deps/tqt/tqt.SlackBuild`): la receta de compilación de TQt, que no usa CMake sino el `configure` heredado de Qt 3. Los flags, las soluciones alternativas del "chequeo" de C++17, los "objetivos" de `make`, y el hecho de que `linux-SB` no es más que una copia de `linux-g++`.
  - **Debian** (`_base/core/tdelibs/debian/control` y `debian/rules`): la lista exhaustiva de build-dependencies, traducida acá a nombres de paquete de Void. Y el dato de que `tde-applications.menu` **no** lo instala el `make install` de tdelibs: hay que copiarlo a mano desde `kded/`. Sin él, el menú de aplicaciones aparece vacío.
  - **Arch** (`tde-core/tde-tdelibs/PKGBUILD`): el mapa de dependencias opcionales, útil para saber qué características existen y qué arrastra cada una.
  - **FreeBSD** (`core/tde-i18n-*/Makefile`): el método para compilar un solo idioma en vez de los 3 GB de traducciones completas.
- **[Wiki oficial de TDE](https://wiki.trinitydesktop.org/)** - el orden de compilación, el bloque de variables de entorno, la excepción de `tqtinterface` a `/usr`, y el `-DCMAKE_SKIP_RPATH=OFF` que tdelibs necesita porque ejecuta binarios durante su propio build.
- **[ArchWiki](https://wiki.archlinux.org/title/Trinity)** - confirmación del uso de `tdebuildsycoca --noincremental`.
- **[Documentación de Void](https://docs.voidlinux.org/xbps/)** — `xlocate` (paquete `xtools`) fue la herramienta que hizo tolerable encontrar qué paquete provee cada header faltante.

El aporte propio de este repositorio es, básicamente, **la traducción de todo eso a Void**, un montón de ajustes, y el descubrimiento de lo que ninguna de esas fuentes documenta: que en x86_64 CMake instala en `lib64` mientras TDE busca sus plugins en `lib`, y que sin un symlink entre ambos el escritorio arranca sin decoraciones de ventana, sin estilos y sin "ioslaves".

## Problemas conocidos

- La cadena instalada es la mínima para un escritorio funcional. Las aplicaciones propias de TDE que están fuera de `tdebase` (tdeutils, tdegraphics, tdepim, etc.) no se compilan.
- `tdebase` se compila completo (`-DBUILD_ALL=ON`), así que trae Konqueror y Konsole aunque no los quieras, porque me di cuenta de que son parte importante del entorno en sí, así como de su ecosistema.
- La variable `libdir` del script apunta a `/opt/trinity/lib`, que no existe hasta que se crea el symlink al final. Funciona, pero es deuda técnica.
- `-DLIB_SUFFIX=""` creo que no tiene efecto: CMake lo ignora y usa `lib64` igual.

## Licencia

GPL v3 o superior.

TDE se distribuye bajo GPL y otras licencias. Ver https://www.trinitydesktop.org/
