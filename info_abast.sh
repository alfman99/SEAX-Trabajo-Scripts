#!/bin/bash

# Bash script template https://betterdev.blog/minimal-safe-bash-script-template/

version_script="0.0.1"
fecha_version="19/05/2022"
nombre_fichero_output="log_abast.txt"

fecha_inicio=$(date '+%Y-%m-%d') # fecha inicio del analisis
hora_inicio=$(date '+%H:%M:%S') # hora inicio del analisis

fecha_final=""
hora_final=""

die() {
  local code=${2-1} # default exit status 1
  exit "$code"
}

usage() {
  cat << EOF # remove the space between << and EOF, this is due to web plugin issue
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -p param_value arg1 [arg2...]

Script description here.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-f, --flag      Some flag description
-p, --param     Some param description
EOF
  die
}

# Parsear los parametros
parse_params() {
  # default values of variables set from params

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ ${#args[@]} -eq -1 ]] && die "Missing script arguments"

  return 0
}

# Check if program has all required packages
comprobar_paquetes_necesarios() {
  programas_necesarios=("cat" "whoami" "grep" "cut" "printf" "echo")
  programas_por_instalar=()

  for program in "${programas_necesarios[@]}"
  do
    if ! command -v "$program" &> /dev/null
    then
      programas_por_instalar+=("$program ")
    fi
  done

  if [ "${programas_por_instalar[0]}" != "" ];
  then
    printf "Para ejecutar este programa necesitas instalar: %s\n" "${programas_por_instalar[@]}"
    die
  fi

  return
}

imprimir_n_lineas() {
  printf " "
  contador=0
  while [ "$contador" -lt "$1" ]
  do
    printf "-"
    ((contador++))
  done
  printf "\n"
}


# Imprimir al final, cuando tengamos todos los datos (fecha_final y hora_final)
print_header() {
  
  text=$(printf "%s\n%s\n%s\n%s" " Identificació de dispositius i xarxes WIFI per l'usuari $(whoami) de l'equip $(cat /etc/hostname)." " Sistema operatiu $(grep ^NAME= /etc/os-release | cut -c7- | cut -d\" -f1) $(grep ^VERSION= /etc/os-release | cut -c10- | cut -d\" -f1)." " Versió del script $version_script compilada el $fecha_version." " Anàlisi iniciada en data $fecha_inicio a les $hora_inicio  i finalitzada en data $fecha_final a les $hora_final.)")
  
  maxima_anchura="$(echo "$text" | wc -L)"

  imprimir_n_lineas "$maxima_anchura"
  echo "$text"
  imprimir_n_lineas "$maxima_anchura"

}

parse_params "$@" # Parsea los parametros introducidos
comprobar_paquetes_necesarios # Comprueba que estén instalados todos los paquetes necesarios para la ejecucion del programa
print_header



# script logic here
