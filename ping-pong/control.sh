#!/bin/bash
# Questo script viene eseguito all'interno delle VM (node1 e node2)
# Attraverso questo piccolo script possiamo analizzare in modo continuo su terminale ssh dei singoli nodi
# la situazione dei docker e vedere se sono attivi o no.

# --- Colori ANSI ---
GREEN='\033[32m'
RED='\033[31m'
BOLD='\033[1m'
RESET='\033[0m'
CYAN='\033[36m'
BLUE='\033[34m'

# --- File segnale di terminazione ---
TERMINATE_FLAG_FILENAME="terminate_vms_flag.signal"
TERMINATE_FLAG_PATH_ON_VM="/vagrant/${TERMINATE_FLAG_FILENAME}" # Percorso all'interno della VM

# Loop infinito per monitorare il file segnale
while true; do
    clear
    if [ -f "$TERMINATE_FLAG_PATH_ON_VM" ]; then
        echo -e "${RED}Rilevato file segnale di terminazione. Uscita dalla shell.${RESET}"
        break # Esci dal loop
    fi
    docker ps
    sleep 1
done

echo -e "${BOLD}${GREEN}--- VM control.sh terminato. ---${RESET}"

exit 0 # Termina lo script e chiudi il terminale SSH