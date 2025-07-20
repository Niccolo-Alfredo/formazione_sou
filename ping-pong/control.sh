#!/bin/bash
# =============================================================================
# SCRIPT: control.sh
# DESCRIZIONE: Questo script viene eseguito all'interno delle VM (node1 e node2)
#              tramite connessioni SSH. Monitora continuamente lo stato dei 
#              container Docker attivi sulla macchina e termina automaticamente
#              quando viene rilevato il file di segnalazione.
# 
# UTILIZZO: Viene chiamato automaticamente da orchestrate_project.sh
# =============================================================================

# --- Configurazione Colori ANSI ---
GREEN='\033[32m'
RED='\033[31m'
BOLD='\033[1m'
RESET='\033[0m'
CYAN='\033[36m'
BLUE='\033[34m'

# --- Configurazione File di Segnalazione ---
# Nome del file che segnala la terminazione del processo
TERMINATE_FLAG_FILENAME="terminate_vms_flag.signal"
# Percorso del file all'interno della VM (accessibile tramite cartella condivisa /vagrant)
TERMINATE_FLAG_PATH_ON_VM="/vagrant/${TERMINATE_FLAG_FILENAME}"

echo -e "${BOLD}${CYAN}=== AVVIO MONITORAGGIO DOCKER SU $(hostname) ===${RESET}"
echo -e "${BLUE}Premi Ctrl+C nel terminale principale per terminare tutti i processi${RESET}"
echo ""

# --- Loop Principale di Monitoraggio ---
# Ciclo infinito che monitora lo stato dei container Docker
while true; do
    # Pulisce il terminale per una visualizzazione più chiara
    clear
    
    # Mostra l'header con informazioni sulla VM corrente
    echo -e "${BOLD}${CYAN}=== MONITORAGGIO DOCKER - $(hostname) ===${RESET}"
    echo -e "${CYAN}Ultimo aggiornamento: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo ""
    
    # Controlla se esiste il file di segnalazione per terminare
    if [ -f "$TERMINATE_FLAG_PATH_ON_VM" ]; then
        echo -e "${RED}${BOLD}File di segnalazione rilevato. Terminazione in corso...${RESET}"
        break # Esce dal loop e termina lo script
    fi
    
    # Mostra lo stato attuale dei container Docker
    echo -e "${BOLD}Container Docker attivi:${RESET}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || {
        echo -e "${RED}Errore nel recupero delle informazioni Docker${RESET}"
    }
    
    echo ""
    echo -e "${CYAN}Controllo file di segnalazione ogni secondo...${RESET}"
    
    # Attende 1 secondo prima del prossimo controllo
    sleep 1
done

# --- Messaggi di Terminazione ---
echo ""
echo -e "${BOLD}${GREEN}=== MONITORAGGIO TERMINATO SU $(hostname) ===${RESET}"
echo -e "${GREEN}Script control.sh completato con successo${RESET}"

# Termina lo script e chiude la connessione SSH
exit 0