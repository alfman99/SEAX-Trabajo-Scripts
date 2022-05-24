#!/bin/bash

version_script="0.0.1"
fecha_version="20/05/2022"
nombre_fichero_output="log_equip.txt"

fecha_inicio=$(date '+%Y-%m-%d') # fecha inicio del analisis
hora_inicio=$(date '+%H:%M:%S') # hora inicio del analisis

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
}


# Imprimir al final, cuando tengamos todos los datos (fecha_final y hora_final)
print_header_start() {
  fecha_final="$(date '+%Y-%m-%d')"
  hora_final="$(date '+%H:%M:%S')"

  text="$(printf "\n%s\n%s\n%s\n%s" " Anàlisi dels usuaris, ports i taules NF actius a l'equip realitzada per l'usuari root de l'equip $(cat /etc/hostname)." " Sistema operatiu $(grep ^NAME= /etc/os-release | cut -c7- | cut -d\" -f1) $(grep ^VERSION= /etc/os-release | cut -c10- | cut -d\" -f1)." " Versió del script $version_script compilada el $fecha_version." " Anàlisi iniciada en data $fecha_inicio a les $hora_inicio i finalitzada en data $fecha_final a les $hora_final.")"
  
  maxima_anchura="$(echo "$text" | wc -L)"

  imprimir_n_lineas "$maxima_anchura"
  echo "$text"
  imprimir_n_lineas "$maxima_anchura"
}

# Hecho
print_usuarios_conectados_sistema() {

  usuarios_activos=$(who | cut -d" " -f1 | tr '\n' ' ')
  num_usuarios_activos="$(who | cut -d" " -f1 | wc -l)"

  texto1="$num_usuarios_activos - $usuarios_activos"

  text="$(printf "\n%-33s%s" "  Usuaris connectats al sistema:" "$texto1")"
  text+="$(printf "\n          %-9s%-13s%-17s%s" "Usuari"   "Terminal"     "Establiment"      "Adreça")"

  data_who=$(who)

  while read usuario
  do
    text+="$(printf "\n          %s" "$usuario" )"
  done < <(echo "$data_who")
  
  echo "$text"

}

print_usuarios_conexiones_activas() {

  format="\n          %-15s%-26s%-12s%-26s%-17s"

  datos_socket="$(ss -ptun)"
  datos_procesos="$(ps -aux)" # la buena

  datos=""

  lista_usuarios=""

  i=1
  while read usuario
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

    datos+="$(printf "$format" "$usuario" "($local_addr" "<->" "$remote_addr" "$pid/$usuario@$terminal")"

  done < <(echo "$datos_socket")

  lista_usuarios="$(echo "$lista_usuarios" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

  text="$(printf "\n%-33s%s%s" "  Usuaris amb conexions actives:" "$(echo "$lista_usuarios" | xargs | tr ' ' '\n' | wc -l) -" "$lista_usuarios")"
  text+="$(printf "$format" "Usuari" "(@IP:Port" "<->" "@IP:Port" "Procés:Usuari)")"
  text+="$datos"

  text=$(echo "$text" | uniq)

  
  echo "$text"


}

print_usuarios_activos() {
  
  texto1="$(whoami)($(id -u)) [pts/$(id -u)]"
  texto2="" #FALTA
  texto3="" #FALTA
  texto4="" #FALTA

  # Usuarios del sistema junto con su UID y PID
  texto5=""
  users="$(cat "/etc/passwd" | tr ':' ' ' | awk '{print $1 " " $3}')"
  while read line
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
  print_ssh_config
  imprimir_n_lineas "$maxima_anchura"

}

# DOING
print_uso_mas_cpu() {

  porcentaje="$1"

  users_active="$(who)"

  while read line
  do
    usuario="$(echo "$line" | awk '{print $1}')"
    procesos="$(top -b -n 1 -u "$usuario")"

    i=1
    while read line
    do
      if [ "$i" -eq 1 ]; then # saltar la primera linea
        ((i++))
        continue
      fi

      # Contar porcentaje de CPU que está siendo utilizada por el usuario
      porcentaje_cpu="$(echo "$line" | awk '{print $9}' | sed -e 's/%//')"


      echo "$usuario"
    done < <(echo "$procesos")

    # Si el porcentaje de CPU calculado en el bucle anterior es mas grande que el parametro de entrada, añadir usuario a la lista para mostrarlo luego

  done < <(echo "$users_active")


}

print_ssh_config() {

  if [ -f "/etc/ssh/sshd_config" ]; then
    value_info="$(grep ^PermitRootLogin= /etc/ssh/sshd_config)"

    if [ -z "$value_info" ]; then
      # No existe el valor, por lo que está por defecto el servidor 
      value_info="Valor commentat"
    else
      value_info="$(echo "$value_info" | cut -d' ' -f2)"
    fi
    
    text="$(printf "\n  %-17s %s" " SSH Usuari root permès:" "$value_info")"

    users_allowed="$(grep ^AllowUsers= /etc/ssh/sshd_config | sed 's/[^ ]* //')" # Borrar todo antes del espacio, para quedarse solo con la lista de usuarios

    if [ -z "$users_allowed" ]; then
      # No existe el valor, por lo que está por defecto el servidor 
      users_allowed="Valor commentat"
    else
      users_allowed="$(echo "$users_allowed")"
    fi

    text+="$(printf "\n  %-17s %s" " SSH Usuaris permesos:" "$users_allowed")"

    echo -e "$text"


  else 
    echo "No hay servidor SSH en esta máquina."
  fi


}

print_ports_actius() {
  header="$(printf "\n%s" " Ports actius detectats al sistema")"
  maxima_anchura="$(echo "$header" | wc -L)"

  imprimir_n_lineas "$maxima_anchura"
  echo "$header"
  imprimir_n_lineas "$maxima_anchura"
}

print_nftables() {

  value_info="\n$(nft list ruleset)"
  maxima_anchura="$(echo "$value_info" | wc -L)"
  header="$(printf "\n%s" " Informació NFTables")"

  imprimir_n_lineas "$maxima_anchura"
  echo "$header"
  imprimir_n_lineas "$maxima_anchura"
  echo -e "$value_info"
  imprimir_n_lineas "$maxima_anchura"

}

# Empieza "main"
comprobar_is_es_root
parse_params "$@" # Parsea los parametros introducidos
comprobar_paquetes_necesarios # Comprueba que estén instalados todos los paquetes necesarios para la ejecucion del programa





{
  # print_header_start
  # echo -e "\n"
  # print_usuarios_activos
  # echo -e "\n\n"
  # print_ports_actius
  # echo -e "\n\n"
  # print_nftables
  # echo -e "\n"
  # print_usuarios_conexiones_activas

  print_uso_mas_cpu

} > "$nombre_fichero_output"

