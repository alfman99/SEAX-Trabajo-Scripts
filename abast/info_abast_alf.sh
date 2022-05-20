#!/bin/bash

version_script="0.0.2"
fecha_version="20/05/2022"
nombre_fichero_output="log_abast.txt"

fecha_inicio=$(date '+%Y-%m-%d') # fecha inicio del analisis
hora_inicio=$(date '+%H:%M:%S') # hora inicio del analisis

fecha_final=""
hora_final=""

tiempo_escaneo=30 # No se como escanear por un tiempo determinado

num_interfaces_wifi="$(iw dev | grep -c ^phy)"

nombres_interfaces_wifi=()
phys_dispositivos_wifi=()

comprobar_is_es_root() {
  if [ "$EUID" -ne 0 ]
  then echo "Porfavor ejecuta este script como root"
    exit
  fi
}

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
-t, --tiempo    Selecciona por cuantos segundos quieres escanear (por defecto: 30)
EOF
  die
}

# Parsear los parametros
parse_params() {
  # default values of variables set from params

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -t | --tiempo) tiempo_escaneo="$2";;
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
  programas_necesarios=("cat" "whoami" "grep" "cut" "printf" "echo" "iw")
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
  contador=1
  while [ "$contador" -lt "$1" ]
  do
    printf "-"
    ((contador++))
  done
  # printf "\n"
}


# Imprimir al final, cuando tengamos todos los datos (fecha_final y hora_final)
print_header_start() {
  
  text="$(printf "%s\n%s\n%s\n%s" " Identificació de dispositius i xarxes WIFI per l'usuari $(whoami) de l'equip $(cat /etc/hostname)." " Sistema operatiu $(grep ^NAME= /etc/os-release | cut -c7- | cut -d\" -f1) $(grep ^VERSION= /etc/os-release | cut -c10- | cut -d\" -f1)." " Versió del script $version_script compilada el $fecha_version." " Anàlisi iniciada en data $fecha_inicio a les $hora_inicio  i finalitzada en data $fecha_final a les $hora_final.)")"
  
  maxima_anchura="$(echo "$text" | wc -L)"

  imprimir_n_lineas "$maxima_anchura"
  echo "$text"
  imprimir_n_lineas "$maxima_anchura"

}

print_punts_access_detectats() {

  contador=1
  while [ "$contador" -le "$num_interfaces_wifi" ]
  do
    nombres_interfaces_wifi+=("$(iw dev | grep 'Interface' | awk '{print $2}' | sed -n "$contador"p)")
    phys_dispositivos_wifi+=("$(iw dev | grep 'phy' | sed -n "$contador"p | sed 's/\#//')")
    ((contador++))
  done

  # Header tabla
  txt_tabla="$(printf "\n %+17s %+5s %+6s %+8s %+9s %+6s %+8s %-28s" "BSSID" "Canal" "Senyal" "Clau" "Xifrat" "Auten." "Vmax" "ESSID" )"
  txt_tabla+="$(printf "\n %+17s %+5s %+6s %+8s %+9s %+6s %+8s %-28s" "-----------------" "-----" "------" "--------" "---------" "------" "--------" "----------------------------")"

  contador=0
  while [ "$contador" -lt "$num_interfaces_wifi" ]
  do

    echo "$contador"

    txt_header="$(printf "\n %s." "Punts d'Accés detecatats (${nombres_interfaces_wifi[$contador]} durant $tiempo_escaneo s)")"
    txt_tabla=""

    # Scan with wifi interface
    redes="$(sudo iw dev "${nombres_interfaces_wifi[$contador]}" scan)"
    redes="${redes}
BSS 00:00:00:00:00:00"

    # Get number of networks found
    num_redes="$(echo "$redes" | grep -c ^BSS)"

    echo "$redes" > "$nombre_fichero_output"

    # For each network found
    i=0
    while [ "$i" -lt "$num_redes" ]
    do
      # Get the BSSID
      bssid="$(echo "$redes" | grep '^BSS '| sed -n "$((i+1))"p | awk '{print $2}' | cut -d\( -f1)"
      if [ "$bssid" == "00:00:00:00:00:00" ];
      then
        break
      fi

      # Seccion del wifi que se esta analizando
      seccion="$(echo "$redes" | sed -n "/$bssid/,/BSS ..:..:..:..:..:../p")"
      
      # Get the channel
      canal="$(echo "$seccion" | grep 'DS Parameter set: channel '| sed -n "$((i+1))"p | awk '{print $NF}')"
      if [ "$canal" == "" ]; then canal="~"; fi
      
      # Get the signal level
      nivel_signal="$(echo "$seccion" | grep 'signal level'| sed -n "$((i+1))"p | awk '{print $3}')"
      if [ "$nivel_signal" == "" ]; then nivel_signal="~"; fi
      
      # Get the type of key
      tipo_key=""
      if [ "$tipo_key" == "" ]; then tipo_key="~"; fi
      
      # Get the cypher (CCMP, TKIP, etc)
      cypher="$(echo "$seccion" | grep 'Pairwise ciphers: ' | awk '{print $4}')"
      if [ "$cypher" == "" ]; then cypher="~"; fi
      
      # Get authentication method (PSK, etc)
      auth="$(echo "$seccion" | grep 'Authentication suites: ' | awk '{print $4}')"
      if [ "$auth" == "" ]; then auth="~"; fi
      
      # Get the supported rates
      rates="$(echo "$seccion" | grep 'Supported rates' | awk '{print $NF}' )"
      if [ "$rates" == "" ]; then rates="~"; fi
      
      # Get the ESSID
      essid=("$(echo "$seccion" | grep 'SSID: ' | awk '{print $2}')")
      if [ "$essid" == "" ]; then essid="~"; fi


      # Print horizontal line
      txt_tabla+="$(printf "\n %+17s %+5s %+6s %+8s %+9s %+6s %+8s %-28s" "$bssid" "$canal" "$nivel_signal" "$tipo_key" "$cypher" "$auth" "$rates" "${essid[@]}")"
      

      ((i++))
    done


    # Print header punts access
    maxima_anchura="$(echo "$txt_tabla" | wc -L)"
    imprimir_n_lineas "$maxima_anchura"
    echo "$txt_header"
    imprimir_n_lineas "$maxima_anchura"
    echo "$txt_tabla"
    imprimir_n_lineas "$maxima_anchura"
    echo -e "\n"

    ((contador++))
  done

}

# Empieza "main"
comprobar_is_es_root
parse_params "$@" # Parsea los parametros introducidos
comprobar_paquetes_necesarios # Comprueba que estén instalados todos los paquetes necesarios para la ejecucion del programa


print_punts_access_detectats

# print_header_start

# script logic here
