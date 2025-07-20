#!/bin/bash
# =============================================================================
# SCRIPT: orchestrate_project.sh
# DESCRIZIONE: Script principale che orchestra l'intero processo di migrazione
#              Docker ping-pong. Gestisce l'avvio delle VM Vagrant, l'apertura
#              dei terminali SSH per il monitoraggio e l'esecuzione dello script
#              di migrazione.
#
# FLUSSO OPERATIVO:
# 1. Avvia le VM con 'vagrant up'
# 2. Apre terminali SSH per monitoraggio (control.sh)  
# 3. Esegue lo script di migrazione container
# 4. Gestisce la terminazione graceful di tutti i processi
# =============================================================================

# --- Configurazione Colori ANSI ---
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Configurazione Progetto ---
# Directory corrente del progetto Vagrant
VAGRANT_PROJECT_DIR="$(pwd)"

# Nomi dei nodi come definiti nel Vagrantfile
NODE1_NAME="node1"
NODE2_NAME="node2"

# --- Configurazione Script ---
# Percorso dello script di migrazione container
MIGRATE_SCRIPT="./migrate_container.sh"

# Percorso dello script di controllo all'interno delle VM
# (accessibile tramite la cartella condivisa /vagrant)
CONTROL_SCRIPT_VM="/vagrant/control.sh"

# --- Configurazione File di Segnalazione ---
TERMINATE_FLAG_FILENAME="terminate_vms_flag.signal"
TERMINATE_FLAG_PATH_ON_VM="/vagrant/${TERMINATE_FLAG_FILENAME}"

# =============================================================================
# FUNZIONI DI SUPPORTO
# =============================================================================

# --- Funzione: Apertura Terminale SSH ---
# Apre un nuovo terminale e si connette alla VM specificata via SSH
open_vagrant_ssh_terminal() {
    local node_name=$1
    local command_to_execute=$2

    echo -e "${CYAN}  Apertura terminale SSH per ${node_name}...${RESET}"

    # Comando SSH completo per Vagrant (con auto-chiusura)
    VAGRANT_SSH_COMMAND="vagrant ssh $node_name -c \"$command_to_execute && exit\""

    # Rilevamento del sistema operativo per scegliere il terminale appropriato
    case "$(uname -s)" in
        Linux*)
            # Prova diversi emulatori di terminale comuni su Linux
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal --window --title="Docker Monitor - $node_name" \
                    -- /usr/bin/env bash -c "cd \"$VAGRANT_PROJECT_DIR\" && $VAGRANT_SSH_COMMAND" &
            elif command -v konsole &> /dev/null; then
                konsole --new-tab -p tabtitle="Docker Monitor - $node_name" \
                    -e /usr/bin/env bash -c "cd \"$VAGRANT_PROJECT_DIR\" && $VAGRANT_SSH_COMMAND" &
            elif command -v xfce4-terminal &> /dev/null; then
                xfce4-terminal --window --title="Docker Monitor - $node_name" \
                    -e "bash -c 'cd \"$VAGRANT_PROJECT_DIR\" && $VAGRANT_SSH_COMMAND'" &
            elif command -v xterm &> /dev/null; then
                xterm -title "Docker Monitor - $node_name" \
                    -e "bash -c 'cd \"$VAGRANT_PROJECT_DIR\" && $VAGRANT_SSH_COMMAND'" &
            else
                echo -e "${YELLOW}  Nessun emulatore di terminale supportato trovato${RESET}"
                echo -e "${YELLOW}   Terminali supportati: gnome-terminal, konsole, xfce4-terminal, xterm${RESET}"
                echo -e "${CYAN}   Comando manuale:${RESET} vagrant ssh $node_name -c \"$command_to_execute && exit\""
            fi
            ;;
        Darwin*) 
            # macOS - usa AppleScript per aprire Terminal.app
            osascript -e "tell application \"Terminal\" to do script \"cd \\\"$VAGRANT_PROJECT_DIR\\\" && vagrant ssh $node_name -c \\\"$command_to_execute && exit\\\"\"" &
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW64*) 
            # Windows (Git Bash, Cygwin, MSYS2)
            echo -e "${YELLOW}  Apertura automatica terminale non supportata su Windows${RESET}"
            echo -e "${CYAN}   Apri manualmente un nuovo terminale e esegui:${RESET}"
            echo -e "${CYAN}   cd \"$VAGRANT_PROJECT_DIR\" && vagrant ssh $node_name -c \"$command_to_execute && exit\"${RESET}"
            ;;
        *)
            # Sistema operativo sconosciuto
            echo -e "${RED} Sistema operativo non riconosciuto${RESET}"
            echo -e "${CYAN}   Comando manuale:${RESET} vagrant ssh $node_name -c \"$command_to_execute && exit\""
            ;;
    esac
    
    # Breve pausa per permettere al terminale di aprirsi
    sleep 2
}

# --- Funzione: Verifica Prerequisiti ---
# Controlla che tutti i file necessari siano presenti
check_prerequisites() {
    echo -e "${BLUE} Verifica prerequisiti...${RESET}"
    
    # Verifica esistenza Vagrantfile
    if [ ! -f "Vagrantfile" ]; then
        echo -e "${RED} Vagrantfile non trovato nella directory corrente${RESET}"
        echo -e "${YELLOW}   Assicurati di essere nella directory del progetto Vagrant${RESET}"
        exit 1
    fi
    
    # Verifica esistenza script di migrazione
    if [ ! -f "$MIGRATE_SCRIPT" ]; then
        echo -e "${RED} Script di migrazione non trovato: $MIGRATE_SCRIPT${RESET}"
        exit 1
    fi
    
    # Verifica esistenza script di controllo
    if [ ! -f "./control.sh" ]; then
        echo -e "${RED} Script di controllo non trovato: ./control.sh${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN} Tutti i prerequisiti soddisfatti${RESET}"
}

# =============================================================================
# PROCESSO PRINCIPALE
# =============================================================================

echo ""
echo -e "${BOLD}${MAGENTA} === ORCHESTRAZIONE PROGETTO DOCKER PING-PONG === ${RESET}"
echo ""

# Verifica prerequisiti
check_prerequisites

# --- Fase 1: Avvio VM Vagrant ---
echo ""
echo -e "${BOLD}${BLUE} FASE 1: Avvio Virtual Machine${RESET}"
echo -e "${BLUE}Esecuzione 'vagrant up' per avviare le VM...${RESET}"
echo ""

# Esegue vagrant up e mostra l'output
vagrant up
if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED} Errore durante l'avvio delle VM Vagrant${RESET}"
    echo -e "${YELLOW}   Controlla i messaggi di errore sopra e risolvi i problemi${RESET}"
    echo -e "${YELLOW}   Poi riprova con: ./orchestrate_project.sh${RESET}"
    exit 1
fi

echo ""
echo -e "${GREEN} VM Vagrant avviate con successo${RESET}"

# --- Fase 2: Apertura Terminali Monitoraggio ---
echo ""
echo -e "${BOLD}${BLUE} FASE 2: Apertura terminali di monitoraggio${RESET}"
echo -e "${BLUE}Apertura terminali SSH per monitoraggio Docker...${RESET}"
echo ""

# Apre terminali SSH separati per ciascun nodo
open_vagrant_ssh_terminal "$NODE1_NAME" "$CONTROL_SCRIPT_VM"
open_vagrant_ssh_terminal "$NODE2_NAME" "$CONTROL_SCRIPT_VM"

echo ""
echo -e "${GREEN} Terminali SSH aperti per entrambi i nodi${RESET}"
echo -e "${CYAN}   Controlla le nuove finestre di terminale per il monitoraggio${RESET}"

# --- Fase 3: Avvio Migrazione Container ---
echo ""
echo -e "${BOLD}${BLUE} FASE 3: Avvio migrazione Docker container${RESET}"
echo ""
echo -e "${YELLOW} Informazioni importanti:${RESET}"
echo -e "${YELLOW}   • Lo script di migrazione verrà eseguito in questo terminale${RESET}"
echo -e "${YELLOW}   • I terminali separati mostreranno lo stato dei container${RESET}"
echo -e "${YELLOW}   • Per interrompere tutto il processo: premi Ctrl+C qui${RESET}"
echo ""
echo -e "${BLUE}Avvio script: $MIGRATE_SCRIPT${RESET}"

# Breve pausa per permettere all'utente di leggere le informazioni
sleep 3

echo ""
echo -e "${BOLD}${GREEN} AVVIO MIGRAZIONE...${RESET}"
echo ""

# Esegue lo script di migrazione (prende il controllo del terminale)
bash "$MIGRATE_SCRIPT"

# --- Fase 4: Completamento ---
# Questo codice viene eseguito solo quando migrate_container.sh termina
echo ""
echo -e "${BOLD}${GREEN} === PROCESSO COMPLETATO ===${RESET}"
echo -e "${GREEN}Tutti i terminali SSH dovrebbero essere chiusi automaticamente${RESET}"
echo -e "${GREEN}Le VM Vagrant sono ancora attive - usa 'vagrant halt' per fermarle${RESET}"
echo ""

exit 0