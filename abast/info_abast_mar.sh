#!/bin/bash

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
  cat <<EOF
Usage: $(info_bash.sh "${BASH_SOURCE[0]}") [-h] [-t] integer arg1 [-i] string arg1
Available options:
-h, --help      Print this help and exit
-t, --tiempo    Selecciona por cuantos segundos quieres escanear (por defecto: 30)
-i, --interfaces Indica para que interficie quiere hacer el análisis, si no se indica nada lo hará para todas.
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
  programas_necesarios=("cat" "whoami" "airodump-ng" "grep" "cut" "printf" "echo" "iw" "aircrack-ng" "airmon-ng")
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
    text="$(timeout --foreground $tiempo_escaneo airodump-ng $1 -w archivoTemp_mk --write-interval 1 -o csv)"
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
comprobar_is_es_root # Comprobamos el root 
comprobar_paquetes_necesarios # Comprueba que estén instalados todos los paquetes necesarios para la ejecucion del programa


version_script="0.0.2"
fecha_version="20/05/2022"

fecha_inicio="$(date '+%Y-%m-%d')" # fecha inicio del analisis
hora_inicio="$(date '+%H:%M:%S')" # hora inicio del analisis

fitxerOutputTmp="$(mktemp)"
$(chmod 700 "$fitxerOutputTmp")
tiempo_escaneo=30
interfice_unica=""

# Comrobamos interficies
re='^[0-9]+$'
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  $(usage())
fi
if [ "$1" == "-t" ] || [ "$1" == "--tiempo" ]; then
  if ! [[ $2 =~ $re ]] ; then
    echo "error: No es un número" >&2; exit 1
  fi
  printf "Cambiando tiempo de 30 segunddos a $2\n"
  tiempo_escaneo="$2"
elif [ "$3" == "-t" ] || [ "$3" == "--tiempo" ]; then
  if ! [[ "$4" =~ $re ]] ; then
    echo "error: No es un número" >&2; exit 1
  fi
  printf "Cambiando tiempo de 30 segunddos a $4\n"
  tiempo_escaneo="$4"
fi
if [ "$1" == "-i" ] || [ "$1" == "--interfaces" ]; then
  valor="$(iw dev | grep $2)"
  if [ -z "$valor" ]; then
    echo "error: No existe la interficie" >&2; exit 1
  fi
  printf "Se analizará solo la interfice $2\n"
  interfice_unica="$2"
elif [ "$3" == "-i" ] || [ "$3" == "--interfaces" ]; then
  valor="$(iw dev | grep $4)"
  if [ -z "$valor" ]; then
    echo "error: No existe la interficie" >&2; exit 1
  fi
  printf "Se analizará solo la interfice $4\n"
  interfice_unica="$4"
fi

file="log_abast.txt"
if [ -f "$file" ] ; then
    $(rm "$file")
fi
$(touch log_abast.txt)

# Checkeamos si solo debemos hacerlo para una interficie
nombres_interfaces_wifi=()
if [ -z "$interfice_unica" ]; then
  interfaces_wifi="$(iw dev | grep -w 'Interface' | awk '{print $2}' )"
  readarray -t nombres_interfaces_wifi <<< "$interfaces_wifi"
else
  nombres_interfaces_wifi="$interfice_unica"
fi

# Scaneamos para las interficies dadas y antes de scanear, activamos el modo monitor. 
# Eliminamos los procesos necesarios para poder activar el modo monitor.
valor="$(airmon-ng check)"
if [ -n "$valor" ]; then
  printf "$valor"
  echo -e "\n"   
  echo "Hay procesos que interfieren, quieres eliminarlos? [S/N]"
  read valor
  resultado=0
  while [ $resultado -ne 1 ]; do
    if [ "$valor" == "S" ]; then
      $(airmon-ng check kill &> /dev/null)
      resultado=1
    elif [ "$valor" == "N" ]; then
      printf "Continue ejecutando bajo su propio riesgo\n"
      resultado=1
    elif [ "$valor" != "Y" ] && [ "$valor" != "N" ]; then
      echo "Hay procesos que interfieren, quieres eliminarlos? [S/N]. Solo se acepta S o N. "
      read valor
    fi
  done
fi

# Checkeamos que interficies están up
AllInterfaces="$(ip link show | awk '{ for (x=1;x<=NR;x+=2) if(FNR==x) print $2 }' | cut -d ":" -f1)"
mapfile -t  AllInterfaces <<< "$AllInterfaces"
InterfacesThatAreUp=()
for ((index=0; index < ${#AllInterfaces[@]}; index++)); do
  estaUp="$(ip a show ${AllInterfaces[index]} up | wc -l)"
  if [ "$estaUp" -ne 0 ]; then
    InterfacesThatAreUp+=("${AllInterfaces[index]}")
  fi
done


for ((index=0; index < ${#nombres_interfaces_wifi[@]}; index++)); do
    $(iwconfig "${nombres_interfaces_wifi[index]}" >> archivo_temp)
    res="$(cat archivo_temp | grep "${nombres_interfaces_wifi[index]}" | grep Monitor)"
    if [ -z "$res" ]; then
      printf "Activando el modo monitor para: "${nombres_interfaces_wifi[index]}"\n"
      $(airmon-ng start "${nombres_interfaces_wifi[index]}" >> archivo_temp2)
      nombres_interfaces_wifi[index]="$(cat archivo_temp2 | grep enabled | awk '{print $7}' | cut -d ] -f2)"
      $(rm archivo_temp2)
    fi
    $(rm archivo_temp)
    printf "Sacando datos para: "${nombres_interfaces_wifi[index]}"\n"
    $(print_punts_access_detectats "${nombres_interfaces_wifi[index]}" >> $fitxerOutputTmp)
    if [ -z "$res" ]; then
      printf "Desactivando el modo monitor para: "${nombres_interfaces_wifi[index]}"\n"
      $(airmon-ng stop "${nombres_interfaces_wifi[index]}" &> /dev/null)
    fi
done

printf "Reiniciando redes locales\n"
for ((index=0; index < ${#InterfacesThatAreUp[@]}; index++)); do
  $(ifdown ${InterfacesThatAreUp[index]} &> /dev/null)
  $(ifup ${InterfacesThatAreUp[index]} &> /dev/null)
done

$(echo $'\n Nota: El valor ~ indica que el paràmetre no és por deduir dels paquets capturats.' >> $fitxerOutputTmp)
$(print_header_start >> $file)
$(cat $fitxerOutputTmp >> $file)


