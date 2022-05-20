#!/bin/bash

version_script="0.0.2"
fecha_version="20/05/2022"
nombre_fichero_output="log_abast.txt"

fecha_inicio="$(date '+%Y-%m-%d')" # fecha inicio del analisis
hora_inicio="$(date '+%H:%M:%S')" # hora inicio del analisis

fitxerOutputTmp="$(mktemp)"
$(chmod 700 "$fitxerOutputTmp")
tiempo_escaneo=30 # No se como escanear por un tiempo determinado

num_interfaces_wifi="$(/sbin/iw dev | grep -c ^phy)"

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
    contador=1
    text_lineas=" "
    while [ "$contador" -lt "$1" ]
    do
        text_lineas+="-"
        ((contador++))
    done
    echo "$text_lineas"
  # printf "\n"
}


# Imprimir al final, cuando tengamos todos los datos (fecha_final y hora_final)
print_header_start() {
  
    fecha_final="$(date '+%Y-%m-%d')" # fecha inicio del analisis
    hora_final="$(date '+%H:%M:%S')" # hora inicio del analisis
    text="$(printf "%s\n%s\n%s\n%s" " Identificació de dispositius i xarxes WIFI per l'usuari $(whoami) de l'equip $(cat /etc/hostname)." " Sistema operatiu $(grep ^NAME= /etc/os-release | cut -c7- | cut -d\" -f1) $(grep ^VERSION= /etc/os-release | cut -c10- | cut -d\" -f1)." " Versió del script $version_script compilada el $fecha_version." " Anàlisi iniciada en data $fecha_inicio a les $hora_inicio  i finalitzada en data $fecha_final a les $hora_final.)")"
  
    maxima_anchura="$(echo "$text" | wc -L)"

    imprimir_n_lineas "$maxima_anchura"
    echo "$text"
    imprimir_n_lineas "$maxima_anchura"
}

print_punts_access_detectats() {
  # Header tabla
    txt_tabla="$(printf "%+18s %+6s %+7s %+9s %+10s %+7s %+9s %-29s" "BSSID" "Canal" "Senyal" "Clau" "Xifrat" "Auten." "Vmax" "ESSID" )"
    txt_tabla+="$(printf "\n %+18s %+6s %+7s %+9s %+10s %+7s %+9s %-29s" "-----------------" "-----" "------" "--------" "---------" "------" "--------" "----------------------------")"
    header_tabla="$(printf "%s." " Punts d'Accés detectats ($1 durant $tiempo_escaneo s)")"
    header_station="$(printf "%s." " Equips Terminals detectats ($1 durant $tiempo_escaneo s)")"
    txt_station="$(printf "%+18s %+7s %+8s %+18s %+13s" "MAC terminal" "Senyal" "Paquets" "BSSID" "ESSID")"
    txt_station+="$(printf "\n %+18s %+7s %+8s %+18s %+13s" "-----------------" "------" "-------" "-----------------" "------------")"
    #Separamos los acces point con los stations
    text="$(timeout --foreground 20 /usr/sbin/airodump-ng $1 -w archivoTemp_mk --write-interval 1 -o csv)"
    numero="$(awk '/Station/{ print NR; exit }' archivoTemp_mk-01.csv)"
    num1="$((numero-1))"
    $(head -n $num1 archivoTemp_mk-01.csv > output1)
    $(tail -n +$numero archivoTemp_mk-01.csv > output2)


    # Obtenemos las columnas
    element="$(cat output1 | awk '{print $1};' | sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_bssid <<< "$element"
    element="$(cat output1 | awk -F ',' '{print $4}' | sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_canal <<< "$element"
    element="$(cat output1 | awk -F ',' '{print $9}' |  sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_senyal <<< "$element"
    element="$(cat output1 | awk -F ',' '{print $6}' |  sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_clau <<< "$element"
    element="$(cat output1 | awk -F ',' '{print $7}' |  sed 's/,//' |sed '1d;2d;$d')"
    readarray -t list_xifrat <<< "$element"
    element="$(cat output1 | awk -F ',' '{print $8}' |  sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_auten <<< "$element"
    element="$(cat output1 | awk -F ',' '{print $5}' |  sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_vmax <<< "$element"
    element="$(cat output1 | awk -F ',' '{print $14}' | sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_essid <<< "$element"
    for ((index=0; index < ${#list_bssid[@]}; index++)); do
        xifrat=${list_xifrat[index]} 
        if [ ${#xifrat} -ne 1 ]; then
            xifrat=${xifrat:1}
            xifrat=${xifrat// //}
        fi
        clau=${list_clau[index]}
        if [ ${#clau} -ne 1 ]; then
            clau=${clau:1}
            clau=${clau// //}
        fi
        vel=${list_vmax[index]}
        if [ $vel == "-1" ]; then
            vel="~ Mbps"
        else
            vel+="Mbps"
        fi
        senyal=${list_senyal[index]}
        if [ $senyal == "-1" ]; then
            senyal="~ dbm"
        else
            senyal+="dbm"
        fi
        txt_tabla+="$(printf "\n %+18s %+6s %+7s %+9s %+10s %+7s %+9s %-29s" "${list_bssid[index]}" "${list_canal[index]}" "$senyal" "${list_clau[index]}" "$xifrat" "$clau" "$vel" "${list_essid[index]}")"
    done
    txt_tabla+="$(printf "\n %+18s %+6s %+7s %+9s %+10s %+7s %+9s %-29s" "-----------------" "-----" "------" "--------" "---------" "------" "--------" "----------------------------")"
    element="$(cat output2 | awk '{print $1};' | sed 's/,//' | sed '1d;$d')"
    readarray -t list_mac <<< "$element"
    element="$(cat output2 | awk -F ',' '{print $4}' | sed 's/,//' | sed '1d;$d')"
    readarray -t list_power <<< "$element"
    element="$(cat output2 | awk -F ',' '{print $5}' |  sed 's/,//' | sed '1d;$d')"
    readarray -t list_paquets <<< "$element"
    element="$(cat output2 | awk -F ',' '{print $6}' |  sed 's/,//' | sed '1d;$d')"
    readarray -t list_bssid <<< "$element"
    element="$(cat output2 | awk -F ',' '{print $7}' |  sed 's/,//' |sed '1d;$d')"
    readarray -t list_essid <<< "$element"
    for ((index=0; index < ${#list_mac[@]}; index++)); do
        senyal=${list_power[index]}
        if [ $senyal == "-1" ]; then
            senyal="~ dbm"
        else
            senyal+="dbm"
        fi
        paquets="$(echo ${list_paquets[index]} | xargs)"
        txt_station+="$(printf "\n %+18s %+7s %+8s %+18s %+13s" "${list_mac[index]}" "$senyal" "$paquets" "${list_bssid[index]}" "${list_essid[index]}")"
    done
    txt_station+="$(printf "\n %+18s %+7s %+8s %+18s %+13s" "-----------------" "------" "-------" "-----------------" "------------")"


    maxima_anchura="$(echo "$txt_tabla" | wc -L)"
    echo -e "\n"
    imprimir_n_lineas "$maxima_anchura"
    echo "$header_tabla"
    imprimir_n_lineas "$maxima_anchura"
    echo "$txt_tabla"
    echo -e "\n"
    imprimir_n_lineas "$maxima_anchura"
    echo "$header_station"
    imprimir_n_lineas "$maxima_anchura"
    echo "$txt_station"
    $(rm archivoTemp_mk-01.csv)
    $(rm output1)
    $(rm output2)
}

# Empieza "main"
comprobar_is_es_root
parse_params "$@" # Parsea los parametros introducidos
# comprobar_paquetes_necesarios # Comprueba que estén instalados todos los paquetes necesarios para la ejecucion del programa

file="log_abast.txt"
if [ -f "$file" ] ; then
    rm "$file"
fi
touch log_abast.txt

nombres_interfaces_wifi=""
# phys_dispositivos_wifi=()
interfaces_wifi="$(/usr/sbin/iw dev  | grep -w 'Interface' | awk '{print $2}' )"
readarray -t nombres_interfaces_wifi <<< "$interfaces_wifi"
 for ((index=0; index < ${#nombres_interfaces_wifi[@]}; index++)); do
    # phys_dispositivos_wifi+=("$(/usr/sbin/iw dev | grep 'phy' | sed -n "$contador"p | sed 's/\#//')")
    print_punts_access_detectats "${nombres_interfaces_wifi[index]}" >> $fitxerOutputTmp
    ((contador++))
done
echo $'\n Nota: El valor ~ indica que el paràmetre no és por deduir dels paquets capturats.' >> $fitxerOutputTmp
print_header_start >> $file
cat $fitxerOutputTmp >> $file


