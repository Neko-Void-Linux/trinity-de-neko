#!/bin/bash

# Extractor de tema de TDE. Se corre DENTRO de una distro con TDE preconfigurado (idealmente dentro de una sesión de TDE ya
# iniciada al menos una vez). Detecta dónde reside la configuración, copia los archivos que definen la apariencia, y resuelve
# los archivos de applet con hash leyendo el "kickerrc". Coloca todo esto en un directorio con el nombre que se le pase.
#
# Uso:  ./extraer_tema.sh nombre_de_la_distro
# Ej.:  ./extraer_tema.sh Q4OS
#
# No se corre como root, sino como el usuario que haya iniciado sesión en un TDE ya configurado.

set -uo pipefail

if [[ $# -lt 1 ]];then
	echo "Uso: $0 nombre_de_la_distro"
	echo "Ejemplo: $0 Q4OS"
	exit 1
fi

distro="$1"
salida="$HOME/temas_tde/$distro"

# Archivos de tema de nombre estable (los mismos que definen la apariencia, sin hash).
archivos_base=(kdeglobals twinrc twinrulesrc kdesktoprc kickerrc ktaskbarrc \
	konsolerc ksplashrc systemtray_panelappletrc kcminputrc kcmdisplayrc \
	gtkrc gtkrc-2.0)

# Directorios de tema.
dirs_base=(colors)

# Encontrar el directorio de configuración de TDE en uso. Prioridad: encontrar la configuración exacta del usuario (la que el usuario ve).
# Si no existe o está vacía, buscar la del sistema ("default" de la distro).
detectar_config() {
	local candidatos=(
		"$HOME/.trinity/share/config"
		"$HOME/.trinity/share/apps/tdedesktop"
		"/opt/trinity/share/config"
		"/etc/trinity/share/config"
		"/usr/share/trinity/config"
	)

	for dir in "${candidatos[@]}";do
		if [[ -f "$dir/kdeglobals" ]] || [[ -f "$dir/kickerrc" ]];then
			echo "$dir"
			return 0
		fi
	done

	# Último recurso, preferentemente evitable: buscar "kdeglobals" en todo el sistema.
	local encontrado
	encontrado=$(find / -name "kdeglobals" 2>/dev/null | head -1)

	if [[ -n "$encontrado" ]];then
		dirname "$encontrado"
		return 0
	fi

	return 1
}

# Leer el "kickerrc" y extraer los nombres de los archivos de configuración de applet que referencie (los que tienen hash).
# De este modo, el tema del panel quedará completo aunque los hashes sean distintos en cada distro.
applets_del_kicker() {
	local kickerrc="$1"

	if [[ ! -f "$kickerrc" ]];then
		return 0
	fi

	# Las líneas son del tipo: ConfigFile[$e]=taskbar_panelapplet_XXXX_rc
	grep -o 'ConfigFile\[\$e\]=[^ ]*' "$kickerrc" 2>/dev/null \
		| cut -d= -f2
}

echo ">> Extrayendo tema de: $distro"

config=$(detectar_config)

if [[ -z "${config:-}" ]];then
	echo "ERROR: no se encontró configuración de TDE en esta máquina."
	echo "¿Estás en TDE? ¿Iniciaste sesión en TDE al menos una vez?"
	exit 1
fi

echo ">> Configuración detectada en: $config"

mkdir -p "$salida"

# Copiar archivos base.
for archivo in "${archivos_base[@]}";do
	if [[ -f "$config/$archivo" ]];then
		cp "$config/$archivo" "$salida/"
		echo "   + $archivo"
	fi
done

# Copiar directorios base.
for dir in "${dirs_base[@]}";do
	if [[ -d "$config/$dir" ]];then
		cp -r "$config/$dir" "$salida/"
		echo "   + $dir/"
	fi
done

# Copiar los archivos de applet referenciados por el kicker (con hash).
while IFS= read -r applet;do
	if [[ -z "$applet" ]];then
		continue
	fi

	if [[ -f "$config/$applet" ]];then
		cp "$config/$applet" "$salida/"
		echo "   + $applet (applet)"
	fi
done < <(applets_del_kicker "$config/kickerrc")

# Detectar rutas "hardcodeadas" con el nombre de usuario, las cuales romperían la "portatilidad" del tema (solo avisa, no modifica).
echo ">> Revisando 'portatilidad'..."

if grep -rl "$HOME" "$salida" 2>/dev/null | grep -q .;then
	echo "   CUIDADO: hay rutas con tu \$HOME adentro de estos archivos:"
	grep -rl "$HOME" "$salida" 2>/dev/null | sed 's/^/     /'
	echo "   Habrá que limpiarlas antes de aplicar el tema a otro usuario."
else
	echo "   CORRECTO: no se encontraron rutas 'hardcodeadas'."
fi

echo -e "\n>> Listo. tema extraído en: $salida"
echo ">> Contenido:"
ls -la "$salida" | sed 's/^/   /'
