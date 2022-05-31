#!/bin/bash
# Autors: Mario Konstanty Kochan Chmielik - 02402638N
# Autors: Alfredo Manresa Martinez - 53874913N

# Comprobamos si el ID del usuario no es igual a 0. Si no es igual a 0, le indicamos que debe ejecutar el script como root y salimos
# del programa.
comprobar_is_es_root() {
  if [ "$EUID" -ne 0 ]
  then echo "Porfavor ejecuta este script como root"
    exit
  fi
}

# Función para hacer un exit() del programa
die() {
  local code=${2-1} # default exit status 1
  exit "$code"
}

# Saca la version y la fecha
version () {
  echo "Version: $version_script"
  echo "Fecha: $fecha_version"

  die
}
# Checkeamos que parametros se le pasa al script
parse_params() {
  # default values of variables set from params

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help) usage ;;
      -v | --version) version ;;
      -i | --interface) 
        valor="$(iw dev | grep "$2")"
        if [ -z "$valor" ]; then
          echo "error: No existe la interficie" >&2; exit 1
        fi
        printf "%s\n" "Se analizará solo la interfice $2"
        interfice_unica="$2"
        shift 2
        ;;
      -t | --tiempo)
        re='^[0-9]+$'
        if ! [[ $2 =~ $re ]] ; then
          echo "error: No es un número" >&2; exit 1
        fi
        printf "%s\n" "Cambiando tiempo de 30 segunddos a $2"
        tiempo_escaneo="$2"
        shift 2
        ;;
      -f | --file)
        file="$2"
        shift 2
        ;;
      --)
        shift;
        break
        ;;
      -?*) die "Unknown option: $1" ;;
      *) break ;;
    esac
  done

  shift $((OPTIND-1))

  return 0
}

# Información del script
usage() {
  cat <<EOF
  Usage: ./info_bash.sh [-h] [-t] integer arg1 [-i] string arg1
  Este script analiza los puntos de acceso y las terminales activas para las interficies red Wi-Fi conectadas al equipo.
  El script analizará por defecto durante 30 segundos todas las interficies Wi-Fi disponibles en la máquina.
  Se puede cambiar el tiempo de escaneo a los segundos que se desee, usando la comanda -t o --tiempo.
  Además, también se puede especificar para que interfície se quiere hacer el análisis. Es sumamente importante que el nombre de
  la interfície esté bien escrita, sinó el programa no funcionará ya que no detectará que existe dicha interfície.

  Durante la ejecución del script, como puede haber procesos que interfieran con el análisis de las redes, se hará matarán estos procesos.
  Esto puede provocar perdidas de conexión a la red. En todo caso, una vez el análisis se ha completado, el script reinicializará las
  interfícies existentes dejandolas en su estado anterior. 
  Por lo tanto, si está trabajando en una máquina remota no se preocupe en perder la conexión establecida. Es parte del proceso
  de análisis del script.

  Puede ocurrir que cuando se ejecute el script se quede en bucle. No entedemos por que pasa esto, ya que no es algo del script
  como tal si no del airodump-ng. En caso que eso suceda, debe reinicar el script. 

  Opciones permitidas:
  -h, --help      Saca el help y sale.
  -t, --tiempo    Selecciona por cuantos segundos quieres escanear (por defecto: 30).
  -i, --interface Indica para que interfície quiere hacer el análisis, si no se indica nada lo hará para todas.
  -v, --version   Se indica la versión del script
  -f, --file      Se indica el fichero de output
EOF
  die
}

# Checkeamos si el usuario tiene instalado todos los programas, si no le sacamos un mensaje de aviso por pantalla.
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

# Imprimimos una cantidad de lineas dependiendo de la longitud que se nos pase por el parámetro. 
imprimir_n_lineas() {
    contador=1
    text_lineas=" "
    while [ "$contador" -lt "$1" ]
    do
        text_lineas+="-"
        ((contador++))
    done
    echo "$text_lineas"
}


# Cabecera del script, aquí se puede modificar si queremos cambiar la cabecera. 
print_header_start() {
  
    fecha_final="$(date '+%Y-%m-%d')" # fecha inicio del analisis
    hora_final="$(date '+%H:%M:%S')" # hora inicio del analisis
    text="$(printf "%s\n%s\n%s\n%s" " Identificació de dispositius i xarxes WIFI per l'usuari $(whoami) de l'equip $(cat /etc/hostname)." " Sistema operatiu $(grep ^NAME= /etc/os-release | cut -c7- | cut -d\" -f1) $(grep ^VERSION= /etc/os-release | cut -c10- | cut -d\" -f1)." " Versió del script $version_script compilada el $fecha_version." " Anàlisi iniciada en data $fecha_inicio a les $hora_inicio  i finalitzada en data $fecha_final a les $hora_final.)")"
  
    maxima_anchura="$(echo "$text" | wc -L)"

    imprimir_n_lineas "$maxima_anchura"
    echo "$text"
    imprimir_n_lineas "$maxima_anchura"
}

# En esta función, obtenemos los resultados del análisis hecho por airodump-ng. Es importante que las interficies esten en modo monitor
# al entrar en dicha función.
print_punts_access_detectats() {
    # Formatos del output
    txt_tabla="$(printf "%+18s %+6s %+7s %+9s %+10s %+7s %+9s %-29s" "BSSID" "Canal" "Senyal" "Clau" "Xifrat" "Auten." "Vmax" "ESSID" )"
    txt_tabla+="$(printf "\n %+18s %+6s %+7s %+9s %+10s %+7s %+9s %-29s" "-----------------" "-----" "------" "--------" "---------" "------" "--------" "----------------------------")"
    header_tabla="$(printf "%s." " Punts d'Accés detectats ($1 durant $tiempo_escaneo s)")"
    header_station="$(printf "%s." " Equips Terminals detectats ($1 durant $tiempo_escaneo s)")"
    txt_station="$(printf "%+18s %+7s %+8s %+18s %+13s" "MAC terminal" "Senyal" "Paquets" "BSSID" "ESSID")"
    txt_station+="$(printf "\n %+18s %+7s %+8s %+18s %+13s" "-----------------" "------" "-------" "-----------------" "------------")"
    # Comprobamos si los archivos temporales que crearemos no existen.
    file_csv_temp="archivoTemp_mk-01.csv"
    if [ -f "$file_csv_temp" ] ; then
      eval "$(rm "$file_csv_temp")"
    fi
    output_1="output1"
    if [ -f "$output_1" ] ; then
      eval "$(rm "$output_1")"
    fi
    output_2="output2"
    if [ -f "$output_2" ] ; then
      eval "$(rm "$output_2")"
    fi
    # Realizamos airodump-ng, escribiendo en el archivo archivoTemp_mk cada segundo, con duración que se nos haya especificado en el main.
    text="$(timeout --foreground "$tiempo_escaneo" airodump-ng "$1" -w archivoTemp_mk --write-interval 1 -o csv)"
    # Para realizar de forma más sencilla los greps, separamos el archivo .csv obtenido en dos.
    # Uno tendrá la parte de los puntos de acceso y otro el de los terminales conectados.
    numero="$(awk '/Station/{ print NR; exit }' "$file_csv_temp")"
    num1="$((numero-1))"
    eval "$(head -n "$num1" "$file_csv_temp" > "$output_1")"
    eval "$(tail -n +"$numero" "$file_csv_temp" > "$output_2")"


    # Obtenemos las columnas de los puntos de acceso obtenidos.
    element="$(< "$output_1" awk '{print $1};' | sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_bssid <<< "$element"
    element="$(< "$output_1" awk -F ',' '{print $4}' | sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_canal <<< "$element"
    element="$(< "$output_1" awk -F ',' '{print $9}' |  sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_senyal <<< "$element"
    element="$(< "$output_1" awk -F ',' '{print $6}' |  sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_clau <<< "$element"
    element="$(< "$output_1" awk -F ',' '{print $7}' |  sed 's/,//' |sed '1d;2d;$d')"
    readarray -t list_xifrat <<< "$element"
    element="$(< "$output_1" awk -F ',' '{print $8}' |  sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_auten <<< "$element"
    element="$(< "$output_1" awk -F ',' '{print $5}' |  sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_vmax <<< "$element"
    element="$(< "$output_1" awk -F ',' '{print $14}' | sed 's/,//' | sed '1d;2d;$d')"
    readarray -t list_essid <<< "$element"
    # Este for los preparamos para darles el formato que nos interesa y lo añadimos en un array de printf.
    for ((index=0; index < ${#list_bssid[@]}; index++)); do
        xifrat=${list_xifrat[index]} 
        if [ ${#xifrat} -ne 1 ]; then
            xifrat=${xifrat:1}
            xifrat=${xifrat// //}
        fi
        auten=${list_auten[index]}
        if [ ${#auten} -ne 1 ]; then
            auten=${auten:1}
        fi
        vel=${list_vmax[index]}
        if [ "$vel" == "-1" ]; then
            vel="~ Mbps"
        else
            vel+="Mbps"
        fi
        senyal=${list_senyal[index]}
        if [ "$senyal" == "-1" ]; then
            senyal="~ dbm"
        else
            senyal+="dbm"
        fi
        txt_tabla+="$(printf "\n %+18s %+6s %+7s %+9s %+10s %+7s %+9s %-29s" "${list_bssid[index]}" "${list_canal[index]}" "$senyal" "${list_clau[index]}" "$xifrat" "$auten" "$vel" "${list_essid[index]}")"
    done
    txt_tabla+="$(printf "\n %+18s %+6s %+7s %+9s %+10s %+7s %+9s %-29s" "-----------------" "-----" "------" "--------" "---------" "------" "--------" "----------------------------")"
    

    # Obtenemos las columnas de los terminales.
    element="$(< "$output_2" awk '{print $1};' | sed 's/,//' | sed '1d;$d')"
    readarray -t list_mac <<< "$element"
    element="$(< "$output_2" awk -F ',' '{print $4}' | sed 's/,//' | sed '1d;$d')"
    readarray -t list_power <<< "$element"
    element="$(< "$output_2" awk -F ',' '{print $5}' |  sed 's/,//' | sed '1d;$d')"
    readarray -t list_paquets <<< "$element"
    element="$(< "$output_2" awk -F ',' '{print $6}' |  sed 's/,//' | sed '1d;$d')"
    readarray -t list_bssid <<< "$element"
    element="$(< "$output_2" awk -F ',' '{print $7}' |  sed 's/,//' |sed '1d;$d')"
    readarray -t list_essid <<< "$element"
    # Este for los preparamos para darles el formato que nos interesa y lo añadimos en un array de printfo 
    for ((index=0; index < ${#list_mac[@]}; index++)); do
        senyal=${list_power[index]}
        if [ "$senyal" == "-1" ]; then
            senyal="~ dbm"
        else
            senyal+="dbm"
        fi
        paquets="$(echo "${list_paquets[index]}" | xargs)"
        txt_station+="$(printf "\n %+18s %+7s %+8s %+18s %+13s" "${list_mac[index]}" "$senyal" "$paquets" "${list_bssid[index]}" "${list_essid[index]}")"
    done
    txt_station+="$(printf "\n %+18s %+7s %+8s %+18s %+13s" "-----------------" "------" "-------" "-----------------" "------------")"

    # Obtenemos el output total y lo sacamos con la comanda echo.
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

    # Eliminamos los archivos temporales que hemos creado.
    eval "$(rm $file_csv_temp)"
    eval "$(rm $output_1)"
    eval "$(rm $output_2)"
}

# Empieza "main"
comprobar_is_es_root # Comprobamos el root 
comprobar_paquetes_necesarios # Comprueba que estén instalados todos los paquetes necesarios para la ejecucion del programa

# inicializamos valores que nos servirán para hacer el header
version_script="2.1.0"
fecha_version="31/05/2022"
fecha_inicio="$(date '+%Y-%m-%d')" # fecha inicio del analisis
hora_inicio="$(date '+%H:%M:%S')" # hora inicio del analisis

# Creamos un archivo temporal que es donde guardaremos en un primer momento los output.
fitxerOutputTmp="$(mktemp)"
# Le asignamos permisos para poder escribir siendo root.
eval "$(chmod 700 "$fitxerOutputTmp")"

# Definimos valores por defecto. 
tiempo_escaneo=30
interfice_unica=""

# Creamos el archivo destino. Pero antes, lo eliminamos si existe.
file="log_abast.txt"
parse_params "$@"
if [ -f "$file" ] ; then
    eval "$(rm "$file")"
fi
eval "$(touch log_abast.txt)"

# Checkeamos si solo debemos hacerlo para una interficie o para todas. Si es para todas, hacemos una lista de ellas.
nombres_interfaces_wifi=()
if [ -z "$interfice_unica" ]; then
  interfaces_wifi="$(iw dev | grep -w 'Interface' | awk '{print $2}' )"
  readarray -t nombres_interfaces_wifi <<< "$interfaces_wifi"
else
  nombres_interfaces_wifi=("$interfice_unica")
fi

# Scaneamos para las interficies dadas y antes de scanear, activamos el modo monitor (Si no está activado.). 
# Eliminamos los procesos necesarios para poder activar el modo monitor.
valor="$(airmon-ng check)"
if [ -n "$valor" ]; then   
  echo "Hay procesos que interfieren, Se van a eliminar. Puede ser que pierda conexión a la red."
  # Checkeamos que interficies estaban UP de antes, para cuando haya que eliminar un proceso poder reiniciarlas.
  AllInterfaces="$(ip link show | awk '{ for (x=1;x<=NR;x+=2) if(FNR==x) print $2 }' | cut -d ":" -f1)"
  mapfile -t  AllInterfaces <<< "$AllInterfaces"
  InterfacesThatAreUp=()
  for ((index=0; index < ${#AllInterfaces[@]}; index++)); do
    estaUp="$(ip a show "${AllInterfaces[index]}" up | wc -l)"
    if [ "$estaUp" -ne 0 ]; then
      InterfacesThatAreUp+=("${AllInterfaces[index]}")
    fi
  done
  eval "$(airmon-ng check kill &> /dev/null)"
fi

# Para cada interficie wifi, activamos el modo monitor si no lo tiene activo y las análizamos. 
# Luego lo desactivamos.
for ((index=0; index < ${#nombres_interfaces_wifi[@]}; index++)); do
    eval "$(iwconfig "${nombres_interfaces_wifi[index]}" >> archivo_temp)"
    res="$(< archivo_temp grep "${nombres_interfaces_wifi[index]}" | grep Monitor)"
    if [ -z "$res" ]; then
      printf "%s\n" "Activando el modo monitor para: ${nombres_interfaces_wifi[index]}"
      eval "$(airmon-ng start "${nombres_interfaces_wifi[index]}" >> archivo_temp2)"
      nombres_interfaces_wifi[index]="$(< archivo_temp2 grep enabled | awk '{print $7}' | cut -d ] -f2)"
      eval "$(rm archivo_temp2)"
    fi
    eval "$(rm archivo_temp)"
    printf "%s\n" "Sacando datos para: ${nombres_interfaces_wifi[index]}"
    eval "$(print_punts_access_detectats "${nombres_interfaces_wifi[index]}" >> "$fitxerOutputTmp")"
    if [ -z "$res" ]; then
      printf "%s\n" "Desactivando el modo monitor para: ${nombres_interfaces_wifi[index]}"
      eval "$(airmon-ng stop "${nombres_interfaces_wifi[index]}" &> /dev/null)"
    fi
done

# En caso de tener que reiniciar redes, se reinician.
printf "%s\n" "Reiniciando redes locales"
for ((index=0; index < ${#InterfacesThatAreUp[@]}; index++)); do
  eval "$(ifdown "${InterfacesThatAreUp[index]}" &> /dev/null)"
  eval "$(ifup "${InterfacesThatAreUp[index]}" &> /dev/null)"
done

# OUTPUT
eval "$(printf "\n%s" "Nota: El valor ~ indica que el paràmetre no és por deduir dels paquets capturats." >> "$fitxerOutputTmp")"
eval "$(print_header_start >> "$file")"
eval "$(cat "$fitxerOutputTmp" >> "$file")"


