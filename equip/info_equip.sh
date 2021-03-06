#!/bin/bash
# Autors: Mario Konstanty Kochan Chmielik - 02402638N
# Autors: Alfredo Manresa Martinez - 53874913N

version_script="1.6.1"
fecha_version="31/05/2022"
nombre_fichero_output="log_equip.txt"

fecha_inicio=$(date '+%Y-%m-%d') # fecha inicio del analisis
hora_inicio=$(date '+%H:%M:%S') # hora inicio del analisis

cpu_threshold=20
mem_threshold=20

# Funcion que comprueba que quien está ejecutando el programa tenga privilegios de superusuario
comprobar_is_es_root() {
  if [ "$EUID" -ne 0 ]
  then echo "Porfavor ejecuta este script como root"
    exit
  fi
}

# Función para cerrar el programa con un codigo númerico.
die() {
  local code=${2-1} # default exit status 1
  exit "$code"
}

# Imprime la versión y el día
version () {
  echo "Version: $version_script"
  echo "Fecha: $fecha_version"

  die
}

usage() {
  cat << EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-c] [-m]

El script de nivel de dispositivo analiza los usuarios, puertos, conexiones y tablas NF del sistema.
Saca toda la información al archivo: "$numero_fichero_output"

Por defecto la script se ejecuta con un threshhold del 20% tanto para la memória como para la CPU.
Esto significa que nos mostrará los usuarios que superen el 20% de memoria o CPU usada.

En caso de no tener servidor SSH instalado en el equipo, simplemente se informa al usuario de esto. En
caso de tener los valores como pueden ser el PermitRootLogin y los usuarios comentados en el archivo de 
configuración, se notifica al usuario.


Opcions disponibles:
-h, --help      Imprime esta ayuda
-v, --version   Imprime la versión y la fecha de la versión
-c, --cpu       Nivell maxim de CPU a partir del qual volem que volem que ens avisin per usuari 
-m, --mem       Nivell maxim de RAM a partir del qual volem que volem que ens avisin per usuari 
-f, --file      Fitxer de sortida de la informació
EOF

  die
}

# Parsear los parametros
parse_params() {
  # default values of variables set from params

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help) usage ;;
      -v | --version) version ;;
      -c | --cpu)
        cpu_threshold="$2"
        shift 2
        ;;
      -m | --mem)
        mem_threshold="$2"
        shift 2
        ;;
      -f | --file)
        nombre_fichero_output="$2"
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

# Comprueba que el sistema tenga todos los programas necesarios para funcionar
comprobar_paquetes_necesarios() {
  programas_necesarios=( "awk" "bc" "cat" "cut" "date" "echo" "getent" "grep" "head" "id" "lscpu" "printf" "ps" "sed" "sort" "ss" "sysctl" "top" "tr" "uniq" "wc" "who" "whoami" "xargs" )
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
}


# Imprimir al header de arriba del todo. Se imprime al final, cuando tengamos todos los datos (fecha_final y hora_final) y se hace un append al fichero final
print_header_start() {
  fecha_final="$(date '+%Y-%m-%d')"
  hora_final="$(date '+%H:%M:%S')"

  text="$(printf "\n%s\n%s\n%s\n%s" " Anàlisi dels usuaris, ports i taules NF actius a l'equip realitzada per l'usuari root de l'equip $(cat /etc/hostname)." " Sistema operatiu $(grep ^NAME= /etc/os-release | cut -c7- | cut -d\" -f1) $(grep ^VERSION= /etc/os-release | cut -c10- | cut -d\" -f1)." " Versió del script $version_script compilada el $fecha_version." " Anàlisi iniciada en data $fecha_inicio a les $hora_inicio i finalitzada en data $fecha_final a les $hora_final.")"
  
  maxima_anchura="$(echo "$text" | wc -L)"

  imprimir_n_lineas "$maxima_anchura"
  echo -e "$text"
  imprimir_n_lineas "$maxima_anchura"
}

# Recolecta información y muestra los datos de que usuarios hay conectados al sistema y en caso de estar conectados remotamente la IP.
print_usuarios_conectados_sistema() {

  usuarios_activos=$(who | cut -d" " -f1 | tr '\n' ' ')
  num_usuarios_activos="$(who | cut -d" " -f1 | wc -l)"

  texto1="$num_usuarios_activos - $usuarios_activos"

  text="$(printf "\n%-33s%s" "  Usuaris connectats al sistema:" "$texto1")"
  text+="$(printf "\n          %-9s%-13s%-17s%s" "Usuari"   "Terminal"     "Establiment"      "Adreça")"

  data_who=$(who)

  while read -r usuario
  do
    text+="$(printf "\n          %s" "$usuario" )"
  done < <(echo "$data_who")
  
  echo "$text"

}

# Recolecta información y muestra los usuarios que tienen conexiones activas de cualquier tipo.
print_usuarios_conexiones_activas() {

  datos_socket="$(ss -ptun)"
  datos_procesos="$(ps -aux)" # la buena

  datos=""

  lista_usuarios=""

  i=1
  vacio=0
  while read -r usuario
  do
    # if i == 1 next iteration and increment i, sirve para que no se imprima el header de la tabla
    if [ "$i" -eq 1 ]; then
      ((i++))
      continue
    fi
    local_addr="$(echo "$usuario" | awk '{print $5}')"
    remote_addr="$(echo "$usuario" | awk '{print $6}')"
    pid="$(echo "$usuario" | awk '{print $7}' | sed -e 's/.*pid=\(.*\),.*/\1/')"

    # buscar el proceso que corresponde al pid
    proceso="$(echo "$datos_procesos" | grep "$pid" | head -n1)"

    usuario="$(echo "$proceso" | awk '{print $1}')"
    terminal="$(echo "$proceso" | awk '{print $7}')"

    if [ "$usuario" == "USER" ]
    then
      continue
    fi

    lista_usuarios+=" $usuario"

    if [ "$usuario" == "" ]
    then
      vacio=1
    fi

    datos+="$(printf "\n          %-15s%-26s%-12s%-26s%-17s" "$usuario" "($local_addr" "<->" "$remote_addr" "$pid/$usuario@$terminal")"

  done < <(echo "$datos_socket")

  lista_usuarios="$(echo "$lista_usuarios" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

  text="$(printf "\n%-33s%s%s" "  Usuaris amb conexions actives:" "$(echo "$lista_usuarios" | xargs | tr ' ' '\n' | wc -l) -" "$lista_usuarios")"
  text+="$(printf "\n          %-15s%-26s%-12s%-26s%-17s" "Usuari" "(@IP:Port" "<->" "@IP:Port" "Procés:Usuari)")"

  if [ "$vacio" -eq 0 ]; then
    text+="$(printf "\n          %-15s%-26s%-12s%-26s%-17s" "-" "-" "-" "-" "-")"
  fi

  text+="$datos"

  text=$(echo "$text" | uniq)  
  echo "$text"

}

# Recolecta información y muestra los usuarios que están activos ahora mismo.
print_usuarios_activos() {
  
  texto1="$(whoami)($(id -u)) [pts/$(id -u)]"
  
  texto2=""
  users_with_shell="$(grep -Ff /etc/shells /etc/passwd | cut -d: -f1)"
  while read -r usuario
  do
    texto2+="$(printf "%s, " "$usuario")"
  done < <(echo "$users_with_shell")

  texto3=""
  users_with_uid_0="$(getent passwd 0 | cut -d: -f1)"

  while read -r usuario
  do
    texto3+="$(printf "%s, " "$(echo "$usuario" | awk '{print $1}')") "
  done < <(echo "$users_with_uid_0")

  

  texto4=""
  usuarios_ps="$(ps -aux | awk '{print $1}' | sed '1 d' | sort | uniq)"

  while read -r line
  do
    num_procesos="$(ps -U "$line" --no-headers 2>/dev/null | wc -l)"
    texto4+="$(printf "%s[%s], " "$line" "$num_procesos")"
  done < <(echo "$usuarios_ps")

  # Usuarios del sistema junto con su UID y PID
  texto5=""
  users="$(< "/etc/passwd" tr ':' ' ' | awk '{print $1 " " $3}')"
  while read -r line
  do
    usuario="$(echo "$line" | cut -d' ' -f1)"
    id="$(echo "$line" | cut -d' ' -f2)"
    texto5+="$(printf "%s(%s)," "$usuario" "$id") "
  done < <(echo "$users")


  text="$(printf "\n %-33s %s \n %-33s %s \n %-34s %s \n %-33s %s \n %-33s %s" " Usuari actual:" "$texto1" " Usuaris operatius:" "$texto2" " Usuaris amb accés root:" "$texto3" " Usuaris amb processos actius:" "$texto4" " Usuaris del sistema:" "$texto5")"
  maxima_anchura="$(echo "$text" | wc -L)"

  header="$(printf "\n%s" " Usuaris actius detectats al sistema")"

  imprimir_n_lineas "$maxima_anchura"
  echo "$header"
  imprimir_n_lineas "$maxima_anchura"
  echo "$text"
  print_usuarios_conectados_sistema
  print_usuarios_conexiones_activas
  print_uso_mas_cpu "$cpu_threshold"
  print_uso_mas_memoria "$mem_threshold"
  echo -e "\n"
  print_ssh_config
  echo -e "\n"
  imprimir_n_lineas "$maxima_anchura"

}

# Recolecta información y muestra los usuarios que tienen un uso de CPU superior a un % determinado.
print_uso_mas_cpu() {

  porcentaje="$1"

  text=""
  text+="$(printf "\n%-33s%s" "  Usuaris amb més CPU>$porcentaje%:" "")"
  text+="$(printf "\n          %-9s%-13s%-17s" "Usuari" "CPU%" "pid/procés")"

  users_active="$(who)"

  vacio=0
  while read -r line
  do
    usuario="$(echo "$line" | awk '{print $1}')"
    cpus=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    procesos="$(top -b -n 1 -u "$usuario" | sed -n '/PID/,$p'|sed '/PID/d')"

    procesamiento_total="0"

    i=1
    while read -r line
    do
      if [ "$i" -eq 1 ]; then # saltar la primera linea
        ((i++))
        continue
      fi

      # Contar porcentaje de CPU que está siendo utilizada por el usuario
      # and replace , with .
      porcentaje_cpu="$(echo "$line" | awk '{print $9}' | sed -e 's/%//' | sed -e 's/,/./')"

      # echo "$porcentaje_cpu"
      procesamiento_total="$(echo "$procesamiento_total + $porcentaje_cpu" | bc)"
      

    done < <(echo "$procesos")

    total_porcentaje=$(echo "$procesamiento_total / $cpus" | bc)

    # Si el porcentaje de CPU calculado en el bucle anterior es mas grande que el parametro de entrada, añadir usuario a la lista para mostrarlo luego

    if [ "$total_porcentaje" -gt "$porcentaje" ]; then
      text+="$(printf "\n          %-9s%-13s%-17s" "$usuario" "$total_porcentaje%" "-/-")"
      vacio=1
    fi
  done < <(echo "$users_active")

  if [ "$vacio" -eq 0 ]; then
    text+="$(printf "\n          %-9s%-13s%-17s" "-" "-%" "-/-")"
  fi

  echo -e "$text"


}


# Recolecta información y muestra los usuarios que tienen un uso de memoria superior a un % determinado.
print_uso_mas_memoria() {
  
  porcentaje="$1"

  text=""
  text+="$(printf "\n%-33s%s" "  Usuaris amb ús de RAM>$porcentaje%:" "")"
  text+="$(printf "\n          %-9s%-13s%-17s" "Usuari" "MEM%" "pid/procés")"

  users_active="$(who)"

  vacio=0
  while read -r line
  do
    usuario="$(echo "$line" | awk '{print $1}')"
    cpus=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    procesos="$(top -b -n 1 -u "$usuario" | sed -n '/PID/,$p'|sed '/PID/d')"

    procesamiento_total="0"

    i=1
    while read -r line
    do
      if [ "$i" -eq 1 ]; then # saltar la primera linea
        ((i++))
        continue
      fi

      # Contar porcentaje de CPU que está siendo utilizada por el usuario
      # and replace , with .
      porcentaje_cpu="$(echo "$line" | awk '{print $10}' | sed -e 's/%//' | sed -e 's/,/./')"

      # echo "$porcentaje_cpu"
      procesamiento_total="$(echo "$procesamiento_total + $porcentaje_cpu" | bc)"
      

    done < <(echo "$procesos")

    total_porcentaje=$(echo "$procesamiento_total / $cpus" | bc)

    # Si el porcentaje de CPU calculado en el bucle anterior es mas grande que el parametro de entrada, añadir usuario a la lista para mostrarlo luego

    if [ "$total_porcentaje" -gt "$porcentaje" ]; then
      text+="$(printf "\n          %-9s%-13s%-17s" "$usuario" "$total_porcentaje%" "-/-")"
      vacio=1
    fi


  done < <(echo "$users_active")

  if [ "$vacio" -eq 0 ]; then
    text+="$(printf "\n          %-9s%-13s%-17s" "-" "-%" "-/-")"
  fi

  echo -e "$text"


}


# Recolección de información del servidor SSH en la máquina
# En caso de no tener servidor SSH se indica también.
print_ssh_config() {

  if [ -f "/etc/ssh/sshd_config" ]; then
    value_info="$(grep ^PermitRootLogin= /etc/ssh/sshd_config)"

    if [ -z "$value_info" ]; then
      # No existe el valor, por lo que está por defecto el servidor 
      value_info="Valor comentado"
    else
      value_info="$(echo "$value_info" | cut -d' ' -f2)"
    fi
    
    text="$(printf "\n  %-17s %s" "SSH Usuari root permès:" "$value_info")"

    users_allowed="$(grep ^AllowUsers= /etc/ssh/sshd_config | sed 's/[^ ]* //')" # Borrar todo antes del espacio, para quedarse solo con la lista de usuarios

    if [ -z "$users_allowed" ]; then
      # No existe el valor, por lo que está por defecto el servidor 
      users_allowed="Valor comentado"
    else
      users_allowed="$(printf "%s" "$users_allowed")"
    fi

    text+="$(printf "\n  %-17s %s" "SSH Usuaris permesos:" "$users_allowed")"

    echo -e "$text"


  else 
    echo "  No hay servidor SSH en esta máquina."
  fi


}

# Busca informacion sobre puertos activos en el sistema y lo muestra 
print_ports_actius() {
  header="$(printf "\n%s" " Ports actius detectats al sistema")"
  
  text_tcp_listen="$(ss -H -ptnl)"
  text="$(printf "  %-20s %-20s %-20s %-20s %-20s %-20s" "State" "Recv-Q" "Send-Q" "Local Address:Port" "Peer Address:Port" "Process")"
  while read -r line
  do
    if [ -z "$line" ]; then
      text+="$(printf "\n  %-20s %-20s %-20s %-20s %-20s %-20s" "-" "-" "-" "-" "-" "-")"
      break
    fi

    State="$(echo "$line" | awk '{print $1}' | sed 's/^ *//g')"
    Recvq="$(echo "$line" | awk '{print $2}' | sed 's/^ *//g')"
    Sendq="$(echo "$line" | awk '{print $3}' | sed 's/^ *//g')"
    Local_Address_Port="$(echo "$line" | awk '{print $4}' | sed 's/^ *//g')"
    Peer_Address_Port="$(echo "$line" | awk '{print $5}' | sed 's/^ *//g')"
    Process="$(echo "$line" | grep -o 'users:.*' | sed 's/^ *//g')"

    if [ "$State" == "" ]; then
      State="-"
    fi
    if [ "$Recvq" == "" ]; then
      Recvq="-"
    fi
    if [ "$Sendq" == "" ]; then
      Sendq="-"
    fi
    if [ "$Local_Address_Port" == "" ]; then
      Local_Address_Port="-"
    fi
    if [ "$Peer_Address_Port" == "" ]; then
      Peer_Address_Port="-"
    fi
    if [ "$Process" == "" ]; then
      Process="-"
    fi

    text+="$(printf "\n  %-20s %-20s %-20s %-20s %-20s %-20s" "$State" "$Recvq" "$Sendq" "$Local_Address_Port" "$Peer_Address_Port" "$Process")"
  done < <(echo "$text_tcp_listen")
  output_text="$(printf "\n Ports TCP en mode LISTEN\n%s" "$text")"


  text_udp_listen="$(ss -H -punl)"
  text="$(printf "  %-20s %-20s %-20s %-20s %-20s %-20s" "State" "Recv-Q" "Send-Q" "Local Address:Port" "Peer Address:Port" "Process")"
  while read -r line
  do
    if [ -z "$line" ]; then
      text+="$(printf "\n  %-20s %-20s %-20s %-20s %-20s %-20s" "-" "-" "-" "-" "-" "-")"
      break
    fi

    State="$(echo "$line" | awk '{print $1}' | sed 's/^ *//g')"
    Recvq="$(echo "$line" | awk '{print $2}' | sed 's/^ *//g')"
    Sendq="$(echo "$line" | awk '{print $3}' | sed 's/^ *//g')"
    Local_Address_Port="$(echo "$line" | awk '{print $4}' | sed 's/^ *//g')"
    Peer_Address_Port="$(echo "$line" | awk '{print $5}' | sed 's/^ *//g')"
    Process="$(echo "$line" | grep -o 'users:.*' | sed 's/^ *//g')"

    if [ "$State" == "" ]; then
      State="-"
    fi
    if [ "$Recvq" == "" ]; then
      Recvq="-"
    fi
    if [ "$Sendq" == "" ]; then
      Sendq="-"
    fi
    if [ "$Peer_Address_Port" == "" ]; then
      Peer_Address_Port="-"
    fi
    if [ "$Process" == "" ]; then
      Process="-"
    fi

    text+="$(printf "\n  %-20s %-20s %-20s %-20s %-20s %-20s" "$State" "$Recvq" "$Sendq" "$Local_Address_Port" "$Peer_Address_Port" "$Process")"
  done < <(echo "$text_udp_listen")
  output_text+="$(printf "\n\n Ports UDP en mode LISTEN\n%s" "$text")"


  text_tcp_established="$(ss -H -ptne)"
  text="$(printf "  %-20s %-20s %-20s %-20s %-20s %-20s" "State" "Recv-Q" "Send-Q" "Local Address:Port" "Peer Address:Port" "Process")"
  while read -r line
  do
    if [ -z "$line" ]; then
      text+="$(printf "\n  %-20s %-20s %-20s %-20s %-20s %-20s" "-" "-" "-" "-" "-" "-")"
      break
    fi

    State="$(echo "$line" | awk '{print $1}' | sed 's/^ *//g')"
    Recvq="$(echo "$line" | awk '{print $2}' | sed 's/^ *//g')"
    Sendq="$(echo "$line" | awk '{print $3}' | sed 's/^ *//g')"
    Local_Address_Port="$(echo "$line" | awk '{print $4}' | sed 's/^ *//g')"
    Peer_Address_Port="$(echo "$line" | awk '{print $5}' | sed 's/^ *//g')"
    Process="$(echo "$line" | grep -o 'users:.*' | sed 's/^ *//g')"

    text+="$(printf "\n  %-20s %-20s %-20s %-20s %-20s %-20s" "$State" "$Recvq" "$Sendq" "$Local_Address_Port" "$Peer_Address_Port" "$Process")"
  done < <(echo "$text_tcp_established")
  output_text+="$(printf "\n\n Ports TCP amb connecxions establertes\n%s" "$text")"


  text_udp_established="$(ss -H -pune)"
  text="$(printf "  %-20s %-20s %-20s %-20s %-20s" "Recv-Q" "Send-Q" "Local Address:Port" "Peer Address:Port" "Process")"
  while read -r line
  do
    if [ -z "$line" ]; then
      text+="$(printf "\n  %-20s %-20s %-20s %-20s %-20s" "-" "-" "-" "-" "-")"
      break
    fi

    Recvq="$(echo "$line" | awk '{print $1}' | sed 's/^ *//g')"
    Sendq="$(echo "$line" | awk '{print $2}' | sed 's/^ *//g')"
    Local_Address_Port="$(echo "$line" | awk '{print $3}' | sed 's/^ *//g')"
    Peer_Address_Port="$(echo "$line" | awk '{print $4}' | sed 's/^ *//g')"
    Process="$(echo "$line" | grep -o 'users:.*' | sed 's/^ *//g')"

    if [ "$Recvq" == "" ]; then
      Recvq="-"
    fi
    if [ "$Sendq" == "" ]; then
      Sendq="-"
    fi
    if [ "$Local_Address_Port" == "" ]; then
      Local_Address_Port="-"
    fi
    if [ "$Peer_Address_Port" == "" ]; then
      Peer_Address_Port="-"
    fi
    if [ "$Process" == "" ]; then
      Process="-"
    fi

    text+="$(printf "\n  %-20s %-20s %-20s %-20s %-20s" "$Recvq" "$Sendq" "$Local_Address_Port" "$Peer_Address_Port" "$Process")"
  done < <(echo "$text_udp_established")
  output_text+="$(printf "\n\n Ports UDP amb connecxions establertes\n%s" "$text")"

  maxima_anchura="$(echo "$output_text" | wc -L)"

  imprimir_n_lineas "$maxima_anchura"
  echo "$header"
  imprimir_n_lineas "$maxima_anchura"
  echo -e "$output_text"
  imprimir_n_lineas "$maxima_anchura"
}

print_nftables() {

  value_info="$(nft list ruleset)"

  text=""

  if [ -n "$value" ]; then
    while read -r line
    do
      text+="$(printf "\n %s" "$line")"
    done < <(echo "$value_info")
  fi

  # if nft list ruleset output is empty, then there are no rules
  if [ -z "$value_info" ]; then
    text+="$(printf "\n%s" "  No n'hi ha cap regla")"
  fi

  maxima_anchura="$(echo "$text" | wc -L)"
  header="$(printf "\n%s" " Informació NFTables")"

  imprimir_n_lineas "$maxima_anchura"
  echo "$header"
  imprimir_n_lineas "$maxima_anchura"
  echo "$text"
  imprimir_n_lineas "$maxima_anchura"

}

# Empieza main 
comprobar_is_es_root
parse_params "$@" # Parsea los parametros introducidos
comprobar_paquetes_necesarios # Comprueba que estén instalados todos los paquetes necesarios para la ejecucion del programa

{
  print_usuarios_activos
  echo -e "\n\n"
  print_ports_actius
  echo -e "\n\n"
  print_nftables
  echo -e "\n"
} > "$nombre_fichero_output"

{
  print_header_start
  echo -e "\n"
} | cat - "$nombre_fichero_output" > temp && mv temp "$nombre_fichero_output"
