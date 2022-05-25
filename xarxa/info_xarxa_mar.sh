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
Uso: $(info_bash.sh "${BASH_SOURCE[0]}") [-h] [-r] integer arg1 [-m] string [TCP/UDP]
El programa analitzará per defecte TCP per a totes les interfícies de la xarxa. 
Es pot fer ús de les següents opciones per tal d'indicar si es vol analitzar per una xarxa en
concret o per un protocol en concret.
Opcions:
-h, --help      Print this help and exit
-r, --red   Se indica que red se va a analizar
-m, --mode Se indica que puertos se analizan, si TCP o UDP. 
-mAll, --mode-all Se indica que se quiere hacer un análisis tanto con TCP como UDP
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
  programas_necesarios=("cat" "whoami" "nmap" "grep" "cut" "printf" "echo" "iw" "hostname")
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

print_header_start() {
  
    fecha_final="$(date '+%Y-%m-%d')" # fecha inicio del analisis
    hora_final="$(date '+%H:%M:%S')" # hora inicio del analisis
    text="$(printf "%s\n%s\n%s\n%s" " Anàlisi dels serveis de la xarxa local realitzada per l'usuari $(whoami) de l'equip $(cat /etc/hostname)." " Sistema operatiu $(grep ^NAME= /etc/os-release | cut -c7- | cut -d\" -f1) $(grep ^VERSION= /etc/os-release | cut -c10- | cut -d\" -f1)." " Versió del script $version_script compilada el $fecha_version." " Anàlisi iniciada en data $fecha_inicio a les $hora_inicio i finalitzada en data $fecha_final a les $hora_final.")"
  
    maxima_anchura="$(echo "$text" | wc -L)"

    imprimir_n_lineas "$maxima_anchura"
    echo "$text"
    imprimir_n_lineas "$maxima_anchura"
}



prints_serveis_xarxa(){
  header_tabla="$(printf "%s." " Anàlisi de Serveis $1 de la xarxa local ($2)")"
  txt_tabla_serveis="$(printf "%+12s %+1s %+15s %+1s" "Port" "Servei" "Num" "@IP")"
  txt_tabla_equips="$(printf "%s %12s %s" " @IP" "Num" "Serveis")"
  if [ "$1" == "TCP" ]; then
    $(nmap $2 -oG archivo_temp &> /dev/null)
  elif [ "$1" == "UDP" ]; then
    $(nmap $2 -sU -oG archivo_temp &> /dev/null)
  fi
  declare -A lista_puertos
  declare -A lista_ip
  while IFS= read -r line 
  do
    valor="$(echo $line | grep Ports | wc -l)"
    if [ "$valor" -eq 1 ]; then
      ip="$(echo $line | awk '{print $2}')"
      element="$(echo $line | sed -n -e 's/^.*Ports: //p')"
      readarray -d ',' -t puertos <<< "$element"
      for ((index=0; index < ${#puertos[@]}; index++)); do
        num_puerto="$(echo "${puertos[index]}" | cut -d / -f1 | sed 's/ //g')"
        protocolo="$(echo "${puertos[index]}" | cut -d / -f3)"
        aplicacion="$(echo "${puertos[index]}" | awk -F// '{print $2}')"
        nombre=$num_puerto'('$protocolo') '$aplicacion
        lista_puertos[$nombre]="${lista_puertos[$nombre]}${lista_puertos[$nombre]:+, }$ip"
        lista_ip[$ip]="${lista_ip[$ip]}${lista_ip[$ip]:+, }$nombre"
      done
    fi
  done < "archivo_temp"

  for key in "${!lista_puertos[@]}"; do 
    readarray -d ',' -t contar_total <<< "${lista_puertos[$key]}"
    first_string="$(echo $key | cut -d ' ' -f1)"
    second_string="$(echo $key | cut -d ' ' -f2)"
    txt_tabla_serveis+="$(printf "\n %11s %-18s %s %s" "$first_string" "$second_string" "[${#contar_total[@]}]" "${lista_puertos[$key]}")"
  done


  for key in "${!lista_ip[@]}"; do 
    readarray -d ',' -t contar_total <<< "${lista_ip[$key]}"
    txt_tabla_equips+="$(printf "\n %-12s %s %s" "$key" "[${#contar_total[@]}]" "${lista_ip[$key]}")"
  done


  header_num_serveis="$(printf " S'han detectat ${#lista_puertos[@]} serveis i ${#lista_ip[@]} equips a la xarxa local.")"
  header_num_equips="$(printf " S'han detectat ${#lista_ip[@]} equips i ${#lista_puertos[@]} serveix a la xarxa local.")"
  maxima_anchura="$(echo "$txt_tabla_serveis" | wc -L)"
  echo -e "\n"
  imprimir_n_lineas "$maxima_anchura"
  echo "$header_tabla"
  echo "$header_num_serveis"
  imprimir_n_lineas "$maxima_anchura"
  echo "$txt_tabla_serveis"                   
  imprimir_n_lineas "$maxima_anchura"
  echo -e "\n"
  maxima_anchura="$(echo "$txt_tabla_equips" | wc -L)"
  imprimir_n_lineas "$maxima_anchura"
  echo "$header_tabla"
  echo "$header_num_equips"
  imprimir_n_lineas "$maxima_anchura"
  echo "$txt_tabla_equips"                   
  imprimir_n_lineas "$maxima_anchura"
  $(rm archivo_temp)
}





# Empieza "main"
comprobar_is_es_root # Comprobamos el root 
comprobar_paquetes_necesarios # Comprueba que estén instalados todos los paquetes necesarios para la ejecucion del programa

version_script="1.0.0"
fecha_version="25/05/2022"

fecha_inicio="$(date '+%Y-%m-%d')" # fecha inicio del analisis
hora_inicio="$(date '+%H:%M:%S')" # hora inicio del analisis

fitxerOutputTmp="$(mktemp)"
$(chmod 700 "$fitxerOutputTmp")
modo="TCP"
ip_unica=""
# Comrobamos interficies
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  $(usage())
fi
if [ "$1" == "-r" ] || [ "$1" == "--red" ]; then
  valor="$(hostname -I | grep $2)"
  if [ -z "$valor" ]; then
    echo "error: No existe una interficie conectada a la red con la IP $2" >&2; exit 1
  fi 
  echo "Se analizará la ip $2"
  ip_unica="$2"
elif [ "$3" == "-r" ] || [ "$3" == "--red" ]; then
  valor="$(hostname -I | grep $4)"
  if [ -z "$valor" ]; then
    echo "error: No existe una interficie conectada a la red con la IP $4" >&2; exit 1
  fi 
  echo "Se analizará la ip $4"
  ip_unica="$4"
fi
if [ "$1" == "-m" ] || [ "$1" == "--mode" ]; then
  if [ "$2" != "UDP" ] && [ "$2" != "TCP" ]; then
    echo "error: No existe el modo. El modo debe ser TCP o UDP" >&2; exit 1
  fi
  modo="$2"
elif [ "$3" == "-m" ] || [ "$3" == "--mode" ]; then
  if [ "$4" != "UDP" ] && [ "$4" != "TCP" ]; then
    echo "error: No existe el modo. El modo debe ser TCP o UDP" >&2; exit 1
  fi
  modo="$4"
elif [ "$1" == "-mAll" ] || [ "$1" == "--mode-all" ]; then
  modo="TCP/UDP"
elif [ "$3" == "-mAll" ] || [ "$3" == "--mode-all" ]; then
  modo="TCP/UDP"
fi

file="log_xarxa.txt"
if [ -f "$file" ] ; then
  $(rm "$file")
fi
$(touch log_xarxa.txt)


local_networks=()
if [ -z "$ip_unica" ]; then
  element="$(hostname -I)"
  readarray -d  ' ' -t local_networks <<< "$element"
else
  local_networks="$ip_unica"
fi
for ((index=0; index < ${#local_networks[@]}-1; index++)); do
  ip_mac_quantity="$(ip a | grep ${local_networks[index]}/ | wc -l)"
  if [ $ip_mac_quantity -ne 0 ]; then
    ip_mac="$(ip a | grep ${local_networks[index]}/ | awk '{print $2}')"
    # Calculem la màscara de la xarxa apartir del numero CIDR.
    # https://gist.github.com/kwilczynski/5d37e1cced7e76c7c9ccfdf875ba6c5b
    CIDR=$(echo "$ip_mac" | awk -F/ '{print $2}')
    value=$(( 0xffffffff ^ ((1 << (32 -  CIDR)) - 1) ))
    netmask=$(( (value >> 24) & 0xff )).$(( (value >> 16) & 0xff )).$(( (value >> 8) & 0xff )).$(( value & 0xff ))
    # Després ho separem per els punts de la propia direcció ip
    IFS=. read -r i1 i2 i3 i4 <<< "${local_networks[index]}"
    IFS=. read -r m1 m2 m3 m4 <<< "$netmask"
    # I fem un and de cadascun
    # https://stackoverflow.com/questions/43876891/given-ip-address-and-netmask-how-can-i-calculate-the-subnet-range-using-bash
    arrayxarxa=$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$((i4 & m4))
    ip_mac=$arrayxarxa'/'$CIDR
    printf "Analizando la red $ip_mac\n"
    if [ "$modo" == "TCP/UDP" ]; then
      $(prints_serveis_xarxa "UDP" $ip_mac >> $fitxerOutputTmp)
      $(prints_serveis_xarxa "TCP" $ip_mac >> $fitxerOutputTmp)
    else
      $(prints_serveis_xarxa $modo $ip_mac >> $fitxerOutputTmp)
    fi
  else
    printf "Analizando la red ${local_networks[index]}\n"
    if [ "$modo" == "TCP/UDP" ]; then
      $(prints_serveis_xarxa "UDP" ${local_networks[index]} >> $fitxerOutputTmp) 
      $(prints_serveis_xarxa "TCP" ${local_networks[index]} >> $fitxerOutputTmp)
    else
      $(prints_serveis_xarxa $modo ${local_networks[index]} >> $fitxerOutputTmp)
    fi
  fi
done
$(print_header_start >> $file)
$(cat $fitxerOutputTmp >> $file)
