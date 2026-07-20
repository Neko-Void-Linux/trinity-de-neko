#!/bin/bash

# Compilador e instalador de Trinity Desktop Environment (TDE) en Void Linux desde las fuentes oficiales (/opt/trinity).

VERSION="0.103.108"

# Idioma de la interfaz. Se compila solo el subdirectorio de este idioma (poco más de 100 MB) desde el repo tde-i18n (que pesaría más de 3 GB completo).
idioma="es"

# Teclado preferido.
layout_teclado="latam"

set -euo pipefail

reset=$'\e[0m'
negro=$'\e[1m'
rojo=$'\e[38;5;203m'
dorado=$'\e[38;5;214m'
verde=$'\e[38;5;114m'
celeste=$'\e[38;5;117m'
gris=$'\e[38;5;244m'
beige=$'\e[38;5;223m'

ctrlc(){
    tput cvvis
    echo -e "\n    ${dorado}Se ha salido limpiamente sin haberse hecho ningún cambio en el sistema.\n${reset}"
    exit 0
}

cartel() {
	clear
	echo -e "\n${dorado}    ╔══════════════════════════════════════════════════════════════════════════╗${reset}"
	echo "${dorado}    ║${reset} ${negro}${rojo}TDEntropía${reset}  ${dorado}·${reset}  ${beige}Instalador de Trinity Desktop Environment para Void Linux${reset} ${dorado}║${reset}"
	echo "${dorado}    ║${reset}                         ${gris}« Le llamaban Trinidad... »${reset}                      ${dorado}║${reset}"
	echo -e "${dorado}    ╚══════════════════════════════════════════════════════════════════════════╝${reset}\n"
}

trap ctrlc SIGINT

clear
cartel
echo -e "    Pulsá alguna tecla para comenzar con la instalación, o [Ctrl] [C] para salir.\n"
tput civis
read -rsn1
tput cvvis

# Auto-elevación: si el script no es ejecutado como root, el mismo es re-lanzado. Si hay root directo, se continúa. sudo eleva.
if [[ $EUID -ne 0 ]];then
	if command -v sudo >/dev/null 2>&1;then
		exec sudo bash "$0" "$@"
	else
		echo -e "${rojo}(!) Este script necesita privilegios de root. No se encontró 'sudo'." >&2
		echo -e "Ejecutalo como root o instalá 'sudo'.${reset}" >&2
		exit 1
	fi
fi

hora_inicio=$(date +%T)
echo -e "${dorado}Hora de inicio: $hora_inicio${reset}"
sleep 1

# Log de la instalación completa, para poder revisar en caso de fallos.
exec > >(tee -a /var/tmp/trinity-instalacion.log) 2>&1
		
# Entorno de build recomendado por el wiki oficial de TDE: todo se instala bajo /opt/trinity, salvo tqtinterface (ver más abajo).
prefijo="/opt/trinity"
sysconfdir="/etc/trinity"
libdir="$prefijo/lib"
mandir="$prefijo/man"
tqtdir="$prefijo/tqt3"

export PATH="$tqtdir/bin:$prefijo/bin:$PATH"
export LD_LIBRARY_PATH="$libdir:$prefijo/lib64:$libdir/trinity:$prefijo/lib64/trinity:$tqtdir/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="$libdir/pkgconfig:$prefijo/lib64/pkgconfig:$tqtdir/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Directorio de trabajo donde se descargan y compilan las fuentes.
trabajo="/var/tmp/trinity-build"

# Base de la API de gitea (para detectar la última versión) y de los tarballs.
gitea_api="https://mirror.git.trinitydesktop.org/gitea/api/v1/repos/TDE"
gitea_archivo="https://mirror.git.trinitydesktop.org/gitea/TDE"

# Versión: se detecta en tiempo de ejecución consultando los tags de tdebase. Se completa en la función correspondiente (vacía, por ahora).
version=""

# Módulos a compilar (en orden). Cada uno depende de los anteriores.
modulos=(tde-cmake tqt tqtinterface dbus-1-tqt tdelibs tdebase)

# Dependencias de build de void (xbps). Se declaran todas; xbps saltea a las que ya estén instaladas.
toolchain=(base-devel cmake ninja pkg-config git rpcsvc-proto bdftopcf xsetroot xmessage xprop xset iceauth)

libs_devel=(libX11-devel libXext-devel libXrender-devel libXrandr-devel \
	libXft-devel libXcursor-devel libXfixes-devel libXi-devel \
	libXtst-devel libSM-devel libICE-devel freetype-devel \
	fontconfig-devel libjpeg-turbo-devel libpng-devel zlib-devel \
	libXinerama-devel dbus-devel libltdl-devel file-devel libXcomposite-devel libxml2-devel libxslt-devel glib-devel alsa-lib-devel \
	openssl-devel cups-devel libudev-devel libXt-devel libtirpc-devel libxkbfile-devel bzip2-devel liblzma-devel pcre2-devel acl-devel attr-devel)
	
# Consultar los tags de tdebase en la API de gitea y obtener la última versión. Los tags vienen ordenados del más nuevo al más viejo.
detectar_version() {
	echo ">> detectando última versión de TDE..."

	version=$(curl -s --retry 3 --retry-delay 2 --max-time 30 "$gitea_api/tdebase/tags?limit=1" \
		| grep -o '"name":"[^"]*"' \
		| head -1 \
		| cut -d'"' -f4)

	if [[ -z "$version" ]];then
		echo "ERROR: no se pudo detectar la versión desde la API de gitea." >&2
		echo "verificá tu conexión o el estado de $gitea_api" >&2
		exit 1
	fi

	echo ">> última versión detectada: $version"
}

# Clonar un módulo desde gitea por su tag de versión. Recibe el nombre del módulo como argumento y utiliza la versión global
# detectada, colocando a las fuentes en $trabajo/<modulo>. Clon superficial (--depth 1) para bajar solo el código del tag,
# sin historial.
descargar_modulo() {
	local modulo="$1"
	local url="$gitea_archivo/$modulo.git"
	local destino="$trabajo/$modulo"

    # El directorio de trabajo puede existir de una ejecución interrumpida anterior (git no clona por encima).
	rm -rf "$destino"
	
	echo ">> clonando $modulo ($version)..."

    git clone --quiet --recurse-submodules --branch "$version" --depth 1 "$url" "$destino"
    
	if [[ ! -d "$destino" ]];then
		echo "ERROR: falló el clonado de $modulo desde $url" >&2
		exit 1
	fi
}

# compilar_tqt: compila e instala tqt (el toolkit, fork de Qt3). Es el único módulo que NO usa cmake: usa el configure heredado de Qt3.
# Receta basada en el SlackBuild oficial de TDE, con set reducido de flags (solo lo necesario para un escritorio; sin cups/nis/mysql).
# instala en $tqtdir (/opt/trinity/tqt3).

compilar_tqt() {
	echo ">> compilando tqt..."
	cd "$trabajo/tqt"

	# tqt exporta su propio directorio como TQTDIR durante el build.
	export TQTDIR="$tqtdir"
	# Solución para reemplazar la detección de compilador del configure por $COMPILER_CXX (hay que establecerla).
   	export COMPILER_CXX="g++"
	# Alternativa del SlackBuild: el chequeo de C++17 del configure falla con gcc moderno si no se fuerza el compilador detectado.
	sed -i 's|COMPILER=`sed.*$|COMPILER=$COMPILER_CXX|' configure

	# configure con set reducido. "yes" responde a la pregunta de licencia.
	# -platform linux-g++: plataforma estándar de 64 bits (el SlackBuild utiliza una copia llamada linux-SB, pero linux-g++ es el original).
	echo "yes" | ./configure \
		-platform linux-g++ \
		-no-exceptions \
		-prefix "$tqtdir" \
		-libdir "$tqtdir/lib" \
		-bindir "$tqtdir/bin" \
		-headerdir "$tqtdir/include/tqt" \
		-plugindir "$tqtdir/lib/tqt/plugins" \
		-datadir "$tqtdir/lib/tqt" \
		-translationdir "$tqtdir/share/tqt/translations" \
		-release \
		-system-zlib \
		-qt-libmng \
		-qt-imgfmt-png \
		-qt-gif \
		-thread \
		-stl \
		-pch \
		-xft \
		-xrender \
		-xrandr \
		-xcursor \
		-xinerama \
		-plugin-style-cde \
		-plugin-style-compact \
		-plugin-style-motif \
		-plugin-style-motifplus \
		-plugin-style-platinum \
		-plugin-style-sgi \
		-plugin-style-windows \
		-fast

	# build con los targets específicos del SlackBuild. el -i ignora un error (no fatal) conocido de PCH (tqtdesignercore).
	make -i symlinks src-qmake src-moc sub-src sub-tools

	# install directo a $tqtdir (mediante root, sin INSTALL_ROOT ni staging).
	make install
}

# compilar_cmake: compila e instala un módulo que usa cmake. recibe el nombre del módulo y el prefijo de instalación como argumentos.
# Receta del wiki oficial (Notes on GIT Sources): build out-of-source en un subdirectorio build/. flags mínimos y limpios.
compilar_cmake() {
	local modulo="$1"
	local prefijo_mod="$2"

	echo ">> compilando $modulo (cmake, prefijo $prefijo_mod)..."

	# build out-of-source: se compila en un sub dirirectorio para no ensuciar el árbol de fuentes.
	local dir_build="$trabajo/$modulo/build"

	mkdir -p "$dir_build"
	rm -rf "$dir_build"/*
	cd "$dir_build"

	# flags comunes a todos los módulos cmake de TDE.
	local flags=(
		-DCMAKE_INSTALL_PREFIX="$prefijo_mod"
		-DSYSCONF_INSTALL_DIR="$sysconfdir"
		-DLIB_SUFFIX=""
		-DMAN_INSTALL_DIR="$mandir"
		-DBUILD_ALL=ON
	)

	# Excepciones por módulo (documentadas en el wiki oficial): tqtinterface necesita saber dónde está tqt.
	if [[ "$modulo" == "tqtinterface" ]];then
		flags+=(-DQT_PREFIX_DIR="$tqtdir")
		flags+=(-DTQT_INCLUDE_DIR="$tqtdir/include/tqt")
		flags+=(-DQT_VERSION=3)
	fi

    # tdelibs ejecuta binarios durante el build: no puede saltear rpath. aRts es el servidor de sonido viejo de KDE3: acá se utiliza ALSA
    # con pulseaudio por encima. O el escritorio se adapta, o... PAREDÓN, no al revés: el sistema NO SE TOCA.
    if [[ "$modulo" == "tdelibs" ]];then
		flags+=(-DCMAKE_SKIP_RPATH=OFF)
		flags+=(-DWITH_ARTS=OFF)
		flags+=(-DWITH_LOGINDPOWER=ON)
	fi

	if [[ "$modulo" == "tdebase" ]];then
		flags+=(-DWITH_ARTS=OFF)
		flags+=(-DHTDIG_SEARCH_BINARY=/usr/bin/false)
	fi
	
	cmake "$trabajo/$modulo" "${flags[@]}"
	make

	# Registro de archivos instalados, para poder revertir después. cmake genera install_manifest.txt con la lista exacta.
	make install

	if [[ -f "$dir_build/install_manifest.txt" ]];then
		mkdir -p "$prefijo/.registro"
		cp "$dir_build/install_manifest.txt" "$prefijo/.registro/$modulo.txt"
	fi
}

# tde-i18n es un repo de más de 3 GB que contiene a todos los idiomas, uno por subdirectorio. Se usa "sparse checkout" para bajar solo el
# necesario, y se compila ese subdirectorio (así lo hace la gente que sabe, es decir, la gente de FreeBSD).
compilar_idioma() {
	echo ">> Compilando traducciones ($idioma)..."

	local destino="$trabajo/tde-i18n"
	local fuente="$destino/tde-i18n-$idioma"

	rm -rf "$destino"

	git clone --quiet --depth 1 --branch "$version" --filter=blob:none --sparse "$gitea_archivo/tde-i18n.git" "$destino"

	cd "$destino"
	git sparse-checkout set "tde-i18n-$idioma" template translations

	if [[ ! -d "$fuente" ]];then
		echo "ERROR: no existe el idioma '$idioma' en tde-i18n." >&2
		exit 1
	fi

	mkdir -p "$fuente/build"
	cd "$fuente/build"
	rm -rf ./*

	cmake "$fuente" -DCMAKE_INSTALL_PREFIX="$prefijo" -DBUILD_ALL=ON
	make
	make install
}

# Instalar con xbps todo lo necesario para compilar TDE. Se declaran todas las dependencias con agnosticismo respecto a lo que haya
# (o esté configurado) en mi sistema, que es el que se está utilizando como base para pruebas.
instalar_dependencias() {
	echo ">> instalando dependencias de build..."
	xbps-install -Sy "${toolchain[@]}" "${libs_devel[@]}"
}

# A continuación, se deja el sistema listo para usar TDE. registra las librerías de /opt/trinity en el "linker" dinámico
# y agrega un perfil que exporta PATH, TQTDIR y demás para todos los usuarios.
configurar_entorno() {
	echo ">> configurando entorno del sistema..."

	# cmake instala lib64 en x86_64, pero TDE busca sus plugins en lib/trinity. Sin este "symlink", twin no encuentra las decoraciones y los widgets quedan sin estilo.
	if [[ ! -e "$prefijo/lib" ]];then
		ln -s "$prefijo/lib64" "$prefijo/lib"
	fi
	
	# Registrar las libs de trinity en el linker dinámico.
    cat > /etc/ld.so.conf.d/trinity.conf <<-EOF
		$libdir
		$prefijo/lib64
		$libdir/trinity
		$prefijo/lib64/trinity
		$tqtdir/lib
	EOF

    chmod -R go+rX "$prefijo"
	ldconfig

	# Perfil de entorno para todos los usuarios.
    cat > /etc/profile.d/trinity.sh <<-EOF
		export TQTDIR="$tqtdir"
		export TDEDIRS="$prefijo"
		export PATH="\$PATH:$tqtdir/bin:$prefijo/bin"
		export PKG_CONFIG_PATH="\${PKG_CONFIG_PATH:-}:$prefijo/lib64/pkgconfig:$tqtdir/lib/pkgconfig"
	EOF

	chmod 644 /etc/profile.d/trinity.sh
}

# Colocar al archivo .desktop en /usr/share/xsessions para que TDE aparezca como opción en la pantalla de login. Es un estándar
# "free"desktop: lo leen todos los gestores (lightdm, sddm, gdm, lxdm...), así que no hace falta detectar cuál usa el sistema.
integrar_sesion() {
	echo ">> integrando TDE a la pantalla de login..."
	mkdir -p /usr/share/xsessions

    cat > /usr/share/xsessions/tde.desktop <<-EOF
		[Desktop Entry]
		Version=1.0
		Type=Application
		Name=Trinity (TDE)
		Comment=Trinity Desktop Environment
		Exec=dbus-launch --exit-with-session $prefijo/bin/starttde
		TryExec=$prefijo/bin/starttde
	EOF

	chmod 644 /usr/share/xsessions/tde.desktop
}

# El make install de tdelibs no instala tde-applications.menu (Debian lo copia a mano en su packaging). Sin este archivo, el menú de aplicaciones de TDE
# aparece vacío (tdebuildsycoca lo busca en /etc/xdg/menus, ignorando XDG_CONFIG_DIRS).
instalar_menu() {
	echo ">> Instalando el menú de aplicaciones..."

	local origen="$trabajo/tdelibs/kded/tde-applications.menu"

	if [[ ! -f "$origen" ]];then
		echo "ERROR: no se encontró $origen" >&2
		exit 1
	fi

	mkdir -p /etc/xdg/menus
	cp "$origen" /etc/xdg/menus/
	chmod 644 /etc/xdg/menus/tde-applications.menu
}

# Aplicar la configuración de escritorio de Entropía binaria a todos los usuarios humanos del sistema (UID >= 1000). Los archivos
# viven en entropia_conf/, junto al script. Cada usuario recibe la config con sus propios permisos, no con los de root.
aplicar_configuracion() {
	echo ">> Aplicando configuración de escritorio..."

	local origen="$(dirname "$(readlink -f "$0")")/entropia_conf"

	if [[ ! -d "$origen" ]];then
		echo "ERROR: no se encontró el directorio $origen" >&2
		echo "El script debe ejecutarse desde el repositorio, con entropia_conf/ en el mismo PATH que el ejecutable BASH." >&2
		exit 1
	fi

	while IFS=: read -r usuario _ uid _ _ home _;do
		if [[ $uid -lt 1000 ]] || [[ $uid -ge 65534 ]];then
			continue
		fi

		if [[ ! -d "$home" ]];then
			continue
		fi

		echo ">> Configurando escritorio para $usuario ($home)..."

		local destino="$home/.trinity/share/config"

		mkdir -p "$destino"
		cp -r "$origen"/* "$destino/"
		
		# Capa "base": servicios esenciales del escritorio que afectan a TODOS los temas.

		# Selector de teclado (kxkb): se muestra siempre (ShowSingle=true), con "layout" latinoamericano por defecto.
		# Si no utilizás este tipo de teclado, cambiá "latam" en "layout_teclado", por "es", "br", "us", etcétera.

		cat > "$destino/kxkbrc" <<-KXKB
			[Layout]
			Layout=$layout_teclado
			Model=pc105
			ShowSingle=true
			Use=true
		KXKB

		# Autostart de kxkb para este usuario.
		mkdir -p "$home/.trinity/Autostart"

		cat > "$home/.trinity/Autostart/kxkb.desktop" <<-KXKBAUTO
			[Desktop Entry]
			Type=Application
			Name=Keyboard Layout
			Exec=kxkb
			X-DCOP-ServiceType=Unique
		KXKBAUTO

		# Submenú "Salir" con "Apagar", "Reiniciar" y "Cerrar sesión". TDE no ofrece estas opciones a usuarios no-root en su diálogo de salida:
		# hay que agregarlas como entradas de menú que usan loginctl (elogind) directamente. El prefijo "ZZ-" las ubica al final del menú.
		local dir_salir="$home/.trinity/share/applnk/ZZ-Salir"
		mkdir -p "$dir_salir"

		cat > "$dir_salir/.directory" <<-SALIR
			[Desktop Entry]
			Type=Directory
			Name=Salir
			Name[es]=Salir
			Icon=system-log-out
		SALIR

		cat > "$dir_salir/apagar.desktop" <<-APAGAR
			[Desktop Entry]
			Type=Application
			Name=Apagar
			Name[es]=Apagar
			Comment=Apagar el equipo
			Exec=loginctl poweroff
			Icon=system-shutdown
		APAGAR

		cat > "$dir_salir/reiniciar.desktop" <<-REINICIAR
			[Desktop Entry]
			Type=Application
			Name=Reiniciar
			Name[es]=Reiniciar
			Comment=Reiniciar el equipo
			Exec=loginctl reboot
			Icon=system-reboot
		REINICIAR

		cat > "$dir_salir/cerrar-sesion.desktop" <<-CERRAR
			[Desktop Entry]
			Type=Application
			Name=Cerrar sesión
			Name[es]=Cerrar sesión
			Comment=Cerrar la sesión actual
			Exec=sh -c "loginctl terminate-session \$XDG_SESSION_ID"
			Icon=system-log-out
		CERRAR
		
		# Permisos correctos para todo lo de este usuario.
		chown -R "$usuario": "$home/.trinity"
	done < /etc/passwd
}

# Borrar el directorio temporal de trabajo con las fuentes.
limpiar() {
	echo ">> limpiando fuentes temporales..."

	# Borrado "hardcodeado" a propósito: NO se utiliza "$trabajo" acá (es la única excepción al uso de la variable en todo el script).
	# Esto es para que, si la variable quedara vacía o mal definida, este rm -rf jamás pueda "cargarse" a otro(s) directorio(s).
	# Si a futuro se altera "trabajo" arriba, hay que cambiar también este "path" a mano.
	rm -rf /var/tmp/trinity-build
}

echo "**** Instalador de 'Trinity Desktop Environment' para Void Linux ****"

instalar_dependencias
detectar_version

mkdir -p "$trabajo"

for modulo in "${modulos[@]}";do
	descargar_modulo "$modulo"
done

# tde-cmake: macros de build. debe instalarse primero.
compilar_cmake "tde-cmake" "$prefijo"

# tqt: el toolkit. único módulo sin cmake.
compilar_tqt

# tqtinterface: EXCEPCIÓN, va a /usr y no a /opt/trinity (wiki oficial).
compilar_cmake "tqtinterface" "/usr"

# El resto de la cadena, va a /opt/trinity.
compilar_cmake "dbus-1-tqt" "$prefijo"
compilar_cmake "tdelibs" "$prefijo"
compilar_cmake "tdebase" "$prefijo"

compilar_idioma
instalar_menu
configurar_entorno
integrar_sesion
aplicar_configuracion
limpiar

hora_fin=$(date +%T)
echo -e "\n**** ¡Todo listo! ****\n"
echo -e "${dorado}Hora de inicio      : "$hora_inicio
echo -e "Hora de finalización: $hora_fin${reset}"
sleep 1
echo "Trinity quedó instalado en $prefijo"
echo "Cerrá sesión y elegí 'Trinity (TDE)' en la pantalla de login."
sleep 1
echo -e "${rojo}\nPara revertir todo:"
echo "  rm -rf $prefijo"
echo "  rm -f /etc/ld.so.conf.d/trinity.conf && ldconfig"
echo "  rm -f /etc/profile.d/trinity.sh"
echo "  rm -f /usr/share/xsessions/tde.desktop"
echo "  rm -f /etc/xdg/menus/tde-applications.menu"
echo -e "  (para tqtinterface en /usr, ver $prefijo/.registro/tqtinterface.txt)\n${reset}"
sleep 1