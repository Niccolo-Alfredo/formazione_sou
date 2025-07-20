#!/bin/bash

# --- Colori ANSI ---
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Configurazione Generale ---
VAGRANT_PROJECT_DIR="$(pwd)"

# Nomi dei nodi Vagrant come definiti nel Vagrantfile
NODE1_NAME="node1"
NODE2_NAME="node2"

# Percorso dello script di migrazione (relativo alla directory del progetto)
MIGRATE_SCRIPT="./migrate_container.sh"

# Nome dello script di controllo da eseguire sulle VM (percorso all'interno della VM)
# Assumiamo che control.sh sia nella stessa directory del Vagrantfile sull'host,
# quindi sarà disponibile su /vagrant/control.sh all'interno della VM.
CONTROL_SCRIPT_VM="/vagrant/control.sh"

# --- Nuovo file segnale di terminazione ---
TERMINATE_FLAG_FILENAME="terminate_vms_flag.signal"
TERMINATE_FLAG_PATH_ON_VM="/vagrant/${TERMINATE_FLAG_FILENAME}" # Percorso all'interno della VM

# Funzione per avviare un terminale SSH con un comando specifico
open_vagrant_ssh_terminal() {
    local node_name=$1 # Es. "node1" o "node2"
    local command_to_execute=$2 # Comando da eseguire all'interno della sessione SSH

    echo -e "${CYAN}Apertura terminale SSH per $node_name con '$command_to_execute'...${RESET}"

    # Modifica chiave qui: Aggiungi '&& exit' per garantire che la sessione SSH si chiuda.
    VAGRANT_SSH_COMMAND="vagrant ssh $node_name -c \"$command_to_execute && exit\""

    # Rilevamento del sistema operativo dell'HOST e comando per aprire il terminale
    case "$(uname -s)" in
        Linux*)
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal --window --title="$node_name SSH" -- /usr/bin/env bash -c "cd \"$VAGRANT_PROJECT_DIR\" && $VAGRANT_SSH_COMMAND" &
            elif command -v konsole &> /dev/null; then
                konsole --new-tab -p tabtitle="$node_name SSH" -e /usr/bin/env bash -c "cd \"$VAGRANT_PROJECT_DIR\" && $VAGRANT_SSH_COMMAND" &
            elif command -v xfce4-terminal &> /dev/null; then
                xfce4-terminal --window --title="$node_name SSH" -e "bash -c 'cd \"$VAGRANT_PROJECT_DIR\" && $VAGRANT_SSH_COMMAND'" &
            elif command -v xterm &> /dev/null; then
                xterm -title "$node_name SSH" -e "bash -c 'cd \"$VAGRANT_PROJECT_DIR\" && $VAGRANT_SSH_COMMAND'" &
            else
                echo -e "${YELLOW}Avviso: Nessun emulatore di terminale comune trovato (gnome-terminal, konsole, xfce4-terminal, xterm).${RESET}"
                echo -e "${YELLOW}Si prega di avviare manualmente 'vagrant ssh $node_name -c \"$command_to_execute && exit\"'.${RESET}"
            fi
            ;;
        Darwin*) # macOS
            osascript -e "tell application \"Terminal\" to do script \"cd \\\"$VAGRANT_PROJECT_DIR\\\" && vagrant ssh $node_name -c \\\"$command_to_execute && exit\\\"\"" &
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW64*) # Windows (Git Bash / Cygwin / MSYS2)
            echo -e "${YELLOW}Avviso: L'apertura automatica di un nuovo terminale su Windows è complessa e non supportata direttamente da questo script.${RESET}"
            echo -e "${YELLOW}Si prega di avviare manualmente un nuovo terminale (es. Git Bash, PowerShell) e poi eseguire:${RESET}"
            echo -e "  ${YELLOW}cd \"$VAGRANT_PROJECT_DIR\" && vagrant ssh $node_name -c \"$command_to_execute && exit\"${RESET}"
            ;;
        *)
            echo -e "${RED}Sistema operativo sconosciuto. Impossibile avviare automaticamente il terminale.${RESET}"
            echo -e "${YELLOW}Si prega di avviare manualmente 'vagrant ssh $node_name -c \"$command_to_execute && exit\"'.${RESET}"
            ;;
    esac
    sleep 2 # Breve pausa per permettere al terminale di aprirsi e connettersi
}

# --- Esecuzione Principale dello Script ---

echo ""
echo -e "${BOLD}${MAGENTA}--- Avvio del processo di automazione Vagrant e Docker ---${RESET}"

# 1. Avvia le VM Vagrant
echo ""
echo -e "${BLUE}Esecuzione di 'vagrant up' per avviare le VM. Questo output sarà visibile qui.${RESET}"
echo ""
vagrant up
if [ $? -ne 0 ]; then
    echo -e "${RED}Errore durante l'avvio delle VM Vagrant. Si prega di risolvere i problemi e riprovare.${RESET}"
    exit 1
fi
echo ""
echo -e "${GREEN}VM Vagrant avviate con successo.${RESET}"

# 2. Apri terminali SSH separati e avvia control.sh su ciascuno
echo ""
echo -e "${BLUE}Apertura di terminali SSH separati per Node 1 e Node 2...${RESET}"
echo ""
# Passiamo il percorso del flag file all'interno della VM allo script control.sh
open_vagrant_ssh_terminal "$NODE1_NAME" "$CONTROL_SCRIPT_VM $TERMINATE_FLAG_PATH_ON_VM"
open_vagrant_ssh_terminal "$NODE2_NAME" "$CONTROL_SCRIPT_VM $TERMINATE_FLAG_PATH_ON_VM"

echo ""
echo -e "${GREEN}Terminale SSH per Node 1 e Node 2 aperti. Controlla le nuove finestre.${RESET}"

# 3. Avvia lo script di migrazione dei container nel terminale corrente
echo ""
echo -e "${BLUE}Avvio dello script di migrazione Docker: $MIGRATE_SCRIPT${RESET}"
echo -e "${BLUE}L'output dello script di migrazione sarà visibile in questo terminale.${RESET}"
echo -e "${BLUE}Per interrompere la migrazione e chiudere i terminali SSH, premi Ctrl+C in questo terminale.${RESET}"
# Esegui lo script di migrazione direttamente in questo terminale.
# Questo script prenderà il controllo del terminale fino a quando non verrà interrotto.

echo ""
bash "$MIGRATE_SCRIPT"

# Quando migrate_container.sh termina (per Ctrl+C), il file segnale viene creato.
# Gli script control.sh lo rileveranno e termineranno.
# Questo script principale terminerà dopo migrate_container.sh.

echo -e "${BOLD}${MAGENTA}--- Processo di automazione completato. ---${RESET}"

exit 0