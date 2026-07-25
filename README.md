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

TDE estaba empaquetado para algunas distros Linux, pero para Void, no. Ahora, los usuarios de Void podemos tener a Trinity.

Hay una solicitud desde el **17 de febrero de 2020**: [issue #19243 de void-packages](https://github.com/void-linux/void-packages/issues/19243) —"Package request: Trinity Desktop Environment", que aún sigue abierta, sin asignar, sin branches ni pull requests.
Este no es un problema exclusivo de Void: en el [issue equivalente de NixOS](https://github.com/NixOS/nixpkgs/issues/108967) un usuario lo resumió así: TDE es muy difícil de instalar en cualquier distribución no soportada. Y tiene toda la razón.
Este repositorio es un intento de resolver eso.

## Estado: **experimental**

El script corrió completo y sin errores, varias veces, en 2 máquinas físicas distintas (nada de virtuales), ambas Void Linux x86_64 con LightDM. El escritorio resultante es funcional y estable.

Lo que **no** está probado: su ejecución en máquinas virtuales, su ejecución fuera de estas 2 máquinas Void mías.

## ¿Qué hace este programa?

Compila e instala la cadena mínima de TDE necesaria para un escritorio funcional:

```
tde-cmake -> tqt -> tqtinterface -> dbus-1-tqt -> tdelibs -> tdebase
```

También se agrega el módulo de traducciones al español, ya que TDE viene en inglés "por omisión".

Todo va a `/opt/trinity`, salvo `tqtinterface` que va a `/usr` (así lo indica el wiki oficial de TDE mientras la migración a CMake esté incompleta).

Al terminar, se hace que TDE aparezca como opción en la pantalla de "login" de LightDM, conviviendo con los escritorios o Window Managers que ya tengas instalados, sin tocarlos ni interferir con ellos en absoluto.

## Requisitos

- Void Linux.
- Conexión a Internet
- Un gestor de sesión gráfico (lo probé con LightDM porque lo uso, pero SDDM, LXDM, etc., deberían funcionar bien con este proyecto, ya que  pueden leer también `/usr/share/xsessions/`)
- Tiempos de espera de ejecución del script proporcionales al hardware existente.

## Ficha técnica

| Dato | Valor |
|---|---|
| Almacenamiento — instalación final | ~500 MB que quedan en `/opt/trinity` y `/etc/trinity` |
| Almacenamiento — durante la compilación | 1.8 GB de descarga (temporal, con limpieza al finalizar) en `/var/tmp/trinity-build` |
| Tiempo — AMD Ryzen 7 5800XT / 32 GB RAM | 15 minutos |
| Tiempo — hardware modesto | Entre 50 y 60 minutos |
| RAM mínima recomendada | *Pendiente de medición, pero se sugiere un mínimo de 8 GB (hay que compilar bastante)* |
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

El directorio `entropia_conf/` contiene una configuración de escritorio que no es la que trae TDE por defecto. El script la aplica a todos los usuarios "humanos" del sistema (UID > 999), sin ser esto un capricho estético. Este TDE recién compilado vino así:

- ventanas minimizadas que no aparecían en el panel (el applet del taskbar no está agregado);
- elementos del panel desparramados sin criterio aparente (unos a la derecha, otros al centro).
- ausencia de elementos básicos, como el reloj;
- aspecto por defecto calco de Windows 2000 (no es un problema la interfaz en sí, sino de dónde viene y los valores que propaga: no me gusta).

La configuración incluida arregla eso. **Todo lo que hay en ella es nativo de TDE**: no agregué ningún ícono externo, ni tema descargado, ni fondo de pantalla bajado de internet. No hay nada foráneo en todo esto: todo es configuración mía utilizando solamente elementos nativos.
Incluye idioma español a Uruguay como país de ubicación geográfica. Si no te es útil esta configuración, solo tenés que tocar un archivo de texto: `entropia_conf/kdeglobals`.
Si preferís la configuración cruda de TDE, podés borrar el contenido de `entropia_conf/` (no el directorio entero, sino, insisto, solo su contenido) antes de correr el script (no lo he probado, pero debería funcionar).

## Configuración del script

Al principio de `trinity.sh` hay dos variables que podés cambiar:

- `idioma` — código del idioma de la interfaz (por defecto `es`). El repositorio `tde-i18n` pesa unos 3 GB completo; el script usa *sparse checkout* de git para bajar únicamente el idioma elegido.
- `prefijo` — dónde se instala TDE (por defecto `/opt/trinity`).

## Decisiones tomadas

- **Sin aRts.** El servidor de sonido de KDE 3 está desactivado (`-DWITH_ARTS=OFF`). TDE usa ALSA "directo"; si tenés PulseAudio, funciona por encima sin conflictos, y a esta decisión la tomé para evitar que 2 servidores de sonido "pelearan" por manejar el "stream" de sonido.
- **Con CUPS.** Los headers se instalan aunque no tengas el daemon corriendo. No arranca ningún servicio: deja TDE listo para cuando quieras imprimir.
- **Sin htdig.** El indexador del centro de ayuda no está empaquetado en Void y su última versión estable es de 2004.
- **Versión más reciente, siempre.** El script consulta la API de la Gitea oficial de TDE y compila la última versión estable publicada. No está clavado ni "hardcodeado" a un número.
- **Sin `-j` en `make`.** La compilación es secuencial. Es más lenta, pero cuando algo falla, el error se lee. En un proyecto experimental esto vale enormemente más que la velocidad de procesamiento.

## Cómo revertir

El script imprime estas instrucciones al terminar:

```
rm -rf /opt/trinity
rm -f /etc/ld.so.conf.d/trinity.conf && ldconfig
rm -f /etc/profile.d/trinity.sh
rm -f /usr/share/xsessions/tde.desktop
rm -f /etc/xdg/menus/tde-applications.menu
```

Para los archivos que `tqtinterface` y `tde-cmake` instalan en `/usr`, el script guarda los manifiestos de CMake en `/opt/trinity/.registro/`. **Copialos antes de borrar `/opt/trinity`** o los perdés.
Las dependencias de compilación instaladas con `xbps`, quedan, al menos, por ahora, ya que no hay un desinstalador. Son "headers", y no interfieren con nada, salvo por el espacio que puedan ocupar, que no es grande. La lista completa está en la matriz `libs_devel` del script.

## De dónde salió cada cosa

Nada de esto se inventó. TDE no publica una lista de dependencias utilizable -la de la wiki oficial arrastra ebuilds de Gentoo de hace más de una década y los propios mantenedores piden que alguien la revise-, así que a la información real hay que obtenerla de los empaquetados de otras distribuciones:

- **[tde-packaging](https://mirror.git.trinitydesktop.org/gitea/TDE/tde-packaging)** — repositorio oficial de empaquetado de TDE. De ahí salió casi todo.
  - **Slackware** (`Deps/tqt/tqt.SlackBuild`): la receta de compilación de TQt, que no usa CMake sino el `configure` heredado de Qt 3. Los flags, las soluciones alternativas del "chequeo" de C++17, los "objetivos" de `make`, y el hecho de que `linux-SB` no es más que una copia de `linux-g++`.
  - **Debian** (`_base/core/tdelibs/debian/control` y `debian/rules`): la lista exhaustiva de build-dependencies, traducida acá a nombres de paquete de Void. Y el dato de que a `tde-applications.menu` **no** lo instala el `make install` de tdelibs: hay que copiarlo a mano desde `kded/`. Sin él, el menú de aplicaciones aparece vacío.
  - **Arch** (`tde-core/tde-tdelibs/PKGBUILD`): el mapa de dependencias opcionales, útil para saber qué características existen y qué arrastra cada una.
  - **FreeBSD** (`core/tde-i18n-*/Makefile`): el método para compilar un solo idioma en vez de los 3 GB de traducciones completas.
- **[Wiki oficial de TDE](https://wiki.trinitydesktop.org/)** - el orden de compilación, el bloque de variables de entorno, la excepción de `tqtinterface` a `/usr`, y el `-DCMAKE_SKIP_RPATH=OFF` que tdelibs necesita porque ejecuta binarios durante su propio build.
- **[ArchWiki](https://wiki.archlinux.org/title/Trinity)** - confirmación del uso de `tdebuildsycoca --noincremental`.
- **[Documentación de Void](https://docs.voidlinux.org/xbps/)** — `xlocate` (paquete `xtools`) fue la herramienta que hizo tolerable encontrar qué paquete provee cada "header" faltante.

El aporte propio de este repositorio es, básicamente, **la traducción de todo eso a Void**, un montón de ajustes, y el descubrimiento de lo que ninguna de esas fuentes documenta: que en "x86_64", CMake instala todo en `lib64` mientras que TDE busca a sus plugins en `lib`, y que sin un symlink entre ambos, el escritorio arranca sin decoraciones de ventana, sin estilos y sin "ioslaves".

## Problemas conocidos

- La cadena instalada es la mínima para un escritorio funcional. Las aplicaciones propias de TDE que están fuera de `tdebase` (tdeutils, tdegraphics, tdepim, etc.) no se compilan.
- `tdebase` se compila completo (`-DBUILD_ALL=ON`), así que trae Konqueror y Konsole aunque no los quieras, porque me di cuenta de que son parte importante del entorno en sí, así como de su ecosistema.
- La variable `libdir` del script apunta a `/opt/trinity/lib`, que no existe hasta que se crea el symlink al final. Funciona, pero es deuda técnica.
- `-DLIB_SUFFIX=""` creo que no tiene efecto: CMake lo ignora y usa `lib64` igualmente.

## Documentación sólida sobre este proyecto y pormenores acerca del mismo

[Trinity en Void Linux: un pedido que llevaba 6 años sin respuesta y que pudo resolver Entropía binaria.](https://entropiabinaria.blogspot.com/2026/07/trinity-en-void-linux-un-pedido-que.html)

## Licencia

GPL v3 o superior.

TDE se distribuye bajo GPL y otras licencias. Ver https://www.trinitydesktop.org/
