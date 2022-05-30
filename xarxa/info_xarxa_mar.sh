#!/bin/bash

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
      -r | --read) 
        valor="$(hostname -I | grep "$2")"
        if [ -z "$valor" ]; then
          echo "error: No existe una interficie conectada a la red con la IP $2" >&2; exit 1
        fi 
        echo "Se analizará la ip $2"
        ip_unica="$2" 
        shift 2
        ;;
      -m | --mode)
        if [ "$2" != "UDP" ] && [ "$2" != "TCP" ]; then
          echo "error: No existe el modo. El modo debe ser TCP o UDP" >&2; exit 1
        fi
        modo="$2"
        shift 2
        ;;
      -mAll | --model-all)
        modo="TCP/UDP"
        shift
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
cat << EOF
  Uso: info_bash.sh [-h] [-r] integer arg1 [-m] string [TCP/UDP]
  El programa analizá las terminales y los puertos que están activos en una red.
  En este script, se puede indicar si se quiere leer una red solo y que protocolos se
  quieren analizar.
  Por defecto, lo que hará es analizar todas las redes para el protocolo TCP.
  En el output, analizará las interficies para las subredes, respetando su CIDR y su rango.
  Puede ocurrir, que para una IP no se pueda obtener la subred a la que pertenece 
  por algun motivo. Para esos casos, analizamos directamente la red mediante la IP.
  Si se quiere hacer un análisis de TCP/UDP, primero se hará un análisis en UDP y luego TCP.
  El programa comprueba que no se le pasen más argumentos de lo debido, que los argumentos que se les pase
  esten bien.
  No se puede usar el comando -m junto con el -mAll, en caso de ponerlo junto, detectará solo el primero.

  Opcions:
  -h, --help        Print this help and exit
  -r, --red         Se indica que red se va a analizar
  -m, --mode        Se indica que puertos se analizan, si TCP o UDP. 
  -v, --version     Se indica la versión del script
  -f, --file        Se indica el fichero de output
  -mAll, --mode-all Se indica que se quiere hacer un análisis tanto con TCP como UDP
EOF
  die
}


# Checkeamos si el usuario tiene instalado todos los programas, si no le sacamos un mensaje de aviso por pantalla.
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
    printf "%s" "Para ejecutar este programa necesitas instalar: %s\n" "${programas_por_instalar[@]}"
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
  # printf "\n"
}

# Cabecera del script, aquí se puede modificar si queremos cambiar la cabecera. 
print_header_start() {
  
    fecha_final="$(date '+%Y-%m-%d')" # fecha inicio del analisis
    hora_final="$(date '+%H:%M:%S')" # hora inicio del analisis
    text="$(printf "%s\n%s\n%s\n%s" " Anàlisi dels serveis de la xarxa local realitzada per l'usuari $(whoami) de l'equip $(cat /etc/hostname)." " Sistema operatiu $(grep ^NAME= /etc/os-release | cut -c7- | cut -d\" -f1) $(grep ^VERSION= /etc/os-release | cut -c10- | cut -d\" -f1)." " Versió del script $version_script compilada el $fecha_version." " Anàlisi iniciada en data $fecha_inicio a les $hora_inicio i finalitzada en data $fecha_final a les $hora_final.")"
  
    maxima_anchura="$(echo "$text" | wc -L)"

    imprimir_n_lineas "$maxima_anchura"
    echo "$text"
    imprimir_n_lineas "$maxima_anchura"
}


# En esta función, obtenemos los resultados del análisis hecho por nmap. Dependiendo de la configuración pasada por parámetros, realizará un análisis 
# para una interficie o varias, en modo TCP, UDP o TCP/UDP
prints_serveis_xarxa(){
  header_tabla="$(printf "%s." " Anàlisi de Serveis $1 de la xarxa local ($2)")"
  txt_tabla_serveis="$(printf "%+12s %+1s %+15s %+1s" "Port" "Servei" "Num" "@IP")"
  txt_tabla_equips="$(printf "%s %12s %s" " @IP" "Num" "Serveis")"
  # Checkeamos si el archivo temporal existe.
  file_csv_temp="archivo_temp"
  if [ -f "$file_csv_temp" ] ; then
      eval "$(rm "$file_csv_temp")"
  fi
  # Miramos en que modo haremos el análisis
  if [ "$1" == "TCP" ]; then
    eval "$(nmap "$2" -sT -oG "$file_csv_temp" &> /dev/null)"
  elif [ "$1" == "UDP" ]; then
    eval "$(nmap "$2" -sU -oG "$file_csv_temp" &> /dev/null)"
  fi
  # Declaramos lista de puertos y listas de ip
  declare -A lista_puertos
  declare -A lista_ip
  # Leemos el archivo temporal que hemos creado linea por linea
  while IFS= read -r line 
  do
    # Como el ouput por cada red, nos saca dos lineas, obtenemos solamente la linea que contenga los puertos.
    valor="$(echo "$line" | grep -c Ports)"
    if [ "$valor" -eq 1 ]; then
      # Para esa linea, obtenemos ip y los elementos que hay después del Ports:
      ip="$(echo "$line" | awk '{print $2}')"
      element="$(echo "$line" | sed -n -e 's/^.*Ports: //p')"
      # Guardamos los elementos que hay después del Ports: en una array. Cada elemento guardado se encuentra separado por una , anteriormente.
      readarray -d ',' -t puertos <<< "$element"
      for ((index=0; index < ${#puertos[@]}; index++)); do
        # Sacamos la información que queremos guardar y la añadimos a las listas de puertos y ip.
        num_puerto="$(echo "${puertos[index]}" | cut -d / -f1 | sed 's/ //g')"
        protocolo="$(echo "${puertos[index]}" | cut -d / -f3)"
        aplicacion="$(echo "${puertos[index]}" | awk -F// '{print $2}')"
        nombre=$num_puerto'('$protocolo') '$aplicacion
        lista_puertos[$nombre]="${lista_puertos[$nombre]}${lista_puertos[$nombre]:+, }$ip"
        lista_ip[$ip]="${lista_ip[$ip]}${lista_ip[$ip]:+, }$nombre"
      done
    fi
  done < $file_csv_temp

  # En esta función le damos el formato que nos interesa.
  for key in "${!lista_puertos[@]}"; do 
    # Contamos la cantidad de ips que hay por puertos para el formato.
    readarray -d ',' -t contar_total <<< "${lista_puertos[$key]}"
    # Separamos el string que contiene la aplicación y el puerto, para poder hacer bien el formato
    first_string="$(echo "$key" | cut -d ' ' -f1)"
    second_string="$(echo "$key" | cut -d ' ' -f2)"
    txt_tabla_serveis+="$(printf "\n %11s %-18s %s %s" "$first_string" "$second_string" "[${#contar_total[@]}]" "${lista_puertos[$key]}")"
  done

  # En esta función le damos el formato que nos interesa.
  for key in "${!lista_ip[@]}"; do 
    # Contamos la cantidad de puertos que hay por una ip para el formato.
    readarray -d ',' -t contar_total <<< "${lista_ip[$key]}"
    txt_tabla_equips+="$(printf "\n %-12s %s %s" "$key" "[${#contar_total[@]}]" "${lista_ip[$key]}")"
  done

  # Creamos el formato
  header_num_serveis="$(printf "%s" " S'han detectat ${#lista_puertos[@]} serveis i ${#lista_ip[@]} equips a la xarxa local.")"
  header_num_equips="$(printf "%s" " S'han detectat ${#lista_ip[@]} equips i ${#lista_puertos[@]} serveix a la xarxa local.")"
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
  eval "$(rm $file_csv_temp)"
}





# Empieza "main"
comprobar_is_es_root # Comprobamos el root 
comprobar_paquetes_necesarios # Comprueba que estén instalados todos los paquetes necesarios para la ejecucion del programa


# inicializamos valores
version_script="2.2.0"
fecha_version="31/05/2022"

fecha_inicio="$(date '+%Y-%m-%d')" # fecha inicio del analisis
hora_inicio="$(date '+%H:%M:%S')" # hora inicio del analisis

# Creamos un archivo temporal que se borra después del reboot
fitxerOutputTmp="$(mktemp)"
# Le asignamos permisos root para poder usarlo.

eval "$(chmod 700 "$fitxerOutputTmp")"
modo="TCP"
ip_unica=""
# Comrobamos los parametros (si hay). En caso que los parametros se pasen mal, se sale del programa.
file="log_xarxa.txt"
parse_params "$@"

# Creamos el archivo donde guardaremos todo.
if [ -f "$file" ] ; then
  eval "$(rm "$file")"
fi
eval "$(touch log_xarxa.txt)"

# Si no nos han pasado una ip, cogemos todas las interficies que hay activas.
declare -a local_networks
if [ -z "$ip_unica" ]; then
  element="$(hostname -I)"
  readarray -d  ' ' -t local_networks <<< "$element"
  # eliminamos el último elemento de la array ya que es un valor vacio
  unset 'local_networks[-1]'
else
  local_networks+=("$ip_unica")
fi

# Hacemos un for con todas las redes que vamos a analizar, dentro de este for las preparamos.
# Destacar que por cada ip, al menos que no tenga la máscara definida, el análisis lo hará 
# para la ip de la subred. 
for ((index=0; index < ${#local_networks[@]}; index++)); do
  ip_mac_quantity="$(ip a | grep -c "${local_networks[index]}"/)"
  if [ "$ip_mac_quantity" -ne 0 ]; then
    ip_mac="$(ip a | grep "${local_networks[index]}"/ | awk '{print $2}')"
    # Calculamos la máscara apartir del CIDR.
    # https://gist.github.com/kwilczynski/5d37e1cced7e76c7c9ccfdf875ba6c5b
    CIDR=$(echo "$ip_mac" | awk -F/ '{print $2}')
    value=$(( 0xffffffff ^ ((1 << (32 -  CIDR)) - 1) ))
    netmask=$(( (value >> 24) & 0xff )).$(( (value >> 16) & 0xff )).$(( (value >> 8) & 0xff )).$(( value & 0xff ))
    # Separamos la máscara y la ip por los puntos que tienen
    IFS=. read -r i1 i2 i3 i4 <<< "${local_networks[index]}"
    IFS=. read -r m1 m2 m3 m4 <<< "$netmask"
    # Y hacemos un and para sacar la subred.
    # https://stackoverflow.com/questions/43876891/given-ip-address-and-netmask-how-can-i-calculate-the-subnet-range-using-bash
    arrayxarxa=$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$((i4 & m4))
    ip_mac=$arrayxarxa'/'$CIDR
    printf "%s\n" "Analizando la red $ip_mac"
    # Dependiendo del modo, analizará de una forma o de otra.
    if [ "$modo" == "TCP/UDP" ]; then
      eval "$(prints_serveis_xarxa "UDP" "$ip_mac" >> "$fitxerOutputTmp")"
      eval "$(prints_serveis_xarxa "TCP" "$ip_mac" >> "$fitxerOutputTmp")"
    else
      eval "$(prints_serveis_xarxa "$modo" "$ip_mac" >> "$fitxerOutputTmp")"
    fi
  else
    # Puede ocurrir que una ip no se nos defina la máscara que tiene. Por eso, en caso que suceda eso, analizamos la red directamente 
    # con la ip.
    printf "%s\n" "Analizando la red ${local_networks[index]}"
    if [ "$modo" == "TCP/UDP" ]; then
      eval "$(prints_serveis_xarxa "UDP" "${local_networks[index]}" >> "$fitxerOutputTmp")" 
      eval "$(prints_serveis_xarxa "TCP" "${local_networks[index]}" >> "$fitxerOutputTmp")"
    else
      eval "$(prints_serveis_xarxa "$modo" "${local_networks[index]}" >> "$fitxerOutputTmp")"
    fi
  fi
done
# Hacemos volcado total de los output a los archivos.
eval "$(print_header_start >> "$file")"
eval "$(cat "$fitxerOutputTmp" >> "$file")"
