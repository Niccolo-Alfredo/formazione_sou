#!/bin/bash
# =============================================================================
# SCRIPT: migrate_container.sh
# DESCRIZIONE: Implementa la migrazione "ping-pong" di un container Docker
#              tra due VM Vagrant. Il container viene alternato tra node1 e 
#              node2 ad intervalli regolari per simulare alta disponibilità.
#
# FUNZIONALITÀ:
# - Avvio automatico del container sul primo nodo
# - Migrazione ciclica tra i due nodi
# - Gestione graceful dell'interruzione (Ctrl+C)
# - Pulizia automatica dei container e file temporanei
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

# --- Configurazione Rete e Nodi ---
# Indirizzi IP dei nodi Vagrant (definiti nel Vagrantfile)
NODE1_IP="192.168.56.101"
NODE2_IP="192.168.56.102"

# Utente SSH per le connessioni alle VM Vagrant
SSH_USER="vagrant"

# --- Configurazione Container Docker ---
# Immagine Docker da utilizzare per il test
CONTAINER_IMAGE="ealen/echo-server"
# Nome del container che verrà creato
CONTAINER_NAME="echo-server"
# Mappatura porta host:container
PORT_MAPPING="8080:80"

# --- Configurazione Temporale ---
# Tempo di attesa tra le migrazioni (in secondi)
SLEEP_TIME=10

# --- Gestione File di Stato ---
# File che tracciano se 'docker run' è già stato eseguito sui nodi
NODE1_RAN_FILE="/tmp/${CONTAINER_NAME}_${NODE1_IP}_ran.flag"
NODE2_RAN_FILE="/tmp/${CONTAINER_NAME}_${NODE2_IP}_ran.flag"

# --- Configurazione File di Segnalazione Terminazione ---
# Nome del file di segnalazione
TERMINATE_FLAG_FILENAME="terminate_vms_flag.signal"
# Percorso del file sull'host (directory corrente)
TERMINATE_FLAG_PATH_ON_HOST="$(pwd)/${TERMINATE_FLAG_FILENAME}"
# Percorso del file all'interno delle VM
TERMINATE_FLAG_PATH_ON_VM="/vagrant/${TERMINATE_FLAG_FILENAME}"

# --- Individuazione Automatica Chiavi SSH Vagrant ---
# Ricerca delle chiavi private SSH per ogni nodo
VAGRANT_SSH_KEY_NODE1=$(find .vagrant/machines/node1/ -name "private_key" 2>/dev/null)
VAGRANT_SSH_KEY_NODE2=$(find .vagrant/machines/node2/ -name "private_key" 2>/dev/null)

# Verifica esistenza delle chiavi SSH
if [ -z "$VAGRANT_SSH_KEY_NODE1" ]; then
    echo -e "${RED}${BOLD}ERRORE:${RESET} ${RED}Chiave SSH per Node1 non trovata.${RESET}"
    echo -e "${YELLOW}Assicurati che il Vagrantfile sia nella directory corrente e che 'vagrant up' sia stato eseguito.${RESET}"
    exit 1
fi

if [ -z "$VAGRANT_SSH_KEY_NODE2" ]; then
    echo -e "${RED}${BOLD}ERRORE:${RESET} ${RED}Chiave SSH per Node2 non trovata.${RESET}"
    echo -e "${YELLOW}Assicurati che il Vagrantfile sia nella directory corrente e che 'vagrant up' sia stato eseguito.${RESET}"
    exit 1
fi

# =============================================================================
# FUNZIONI PRINCIPALI
# =============================================================================

# --- Funzione: Esecuzione Comando Remoto ---
# Esegue un comando su un nodo remoto tramite SSH e gestisce l'output
execute_remote_command() {
    local node_ip=$1
    local ssh_key=$2
    local command_to_execute=$3
    local success_message=$4
    local error_message=$5

    # Opzioni SSH:
    # -q: modalità silenziosa per ridurre output verboso
    # -o StrictHostKeyChecking=no: evita prompt di conferma per nuovi host
    ssh -q -i "$ssh_key" -o StrictHostKeyChecking=no "$SSH_USER"@"$node_ip" "$command_to_execute"
    
    # Controlla il codice di uscita del comando SSH
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${success_message}${RESET}"
    else
        echo -e "${RED}✗ ${error_message}${RESET}"
    fi
}

# --- Funzione: Avvio/Riavvio Container ---
# Gestisce l'avvio del container, distinguendo tra prima esecuzione e riavvii
run_or_start_container() {
    local node_ip=$1
    local ssh_key=$2
    local node_ran_flag_file=$3

    echo ""
    echo -e "${CYAN} Avvio container '${CONTAINER_NAME}' su ${node_ip}...${RESET}"

    if [ ! -f "$node_ran_flag_file" ]; then
        # Prima esecuzione: usa 'docker run' dopo aver pulito eventuali container precedenti
        execute_remote_command "$node_ip" "$ssh_key" \
            "docker stop $CONTAINER_NAME >/dev/null 2>&1 || true && \
             docker rm $CONTAINER_NAME >/dev/null 2>&1 || true && \
             docker run -d --name $CONTAINER_NAME -p $PORT_MAPPING $CONTAINER_IMAGE >/dev/null 2>&1" \
            "Container '${CONTAINER_NAME}' creato e avviato su ${node_ip}" \
            "Errore nella creazione del container '${CONTAINER_NAME}' su ${node_ip}"
        
        # Crea il file flag per indicare che il container è stato creato
        touch "$node_ran_flag_file"
    else
        # Esecuzioni successive: usa 'docker start' 
        execute_remote_command "$node_ip" "$ssh_key" \
            "docker start $CONTAINER_NAME >/dev/null 2>&1" \
            "Container '${CONTAINER_NAME}' riavviato su ${node_ip}" \
            "Errore nel riavvio del container '${CONTAINER_NAME}' su ${node_ip}"
    fi
}

# --- Funzione: Arresto Container ---
# Ferma il container su un nodo specifico (senza rimuoverlo)
stop_container() {
    local node_ip=$1
    local ssh_key=$2

    echo ""
    echo -e "${YELLOW} Arresto container '${CONTAINER_NAME}' su ${node_ip}...${RESET}"
    
    execute_remote_command "$node_ip" "$ssh_key" \
        "docker stop $CONTAINER_NAME >/dev/null 2>&1 || true" \
        "Container '${CONTAINER_NAME}' arrestato su ${node_ip}" \
        "Container '${CONTAINER_NAME}' non era attivo su ${node_ip} o errore durante l'arresto"
}

# --- Funzione: Pulizia Sistema ---
# Funzione chiamata all'interruzione del processo (Ctrl+C)
cleanup() {
    echo ""
    echo -e "${BOLD}${RED} INTERRUZIONE RILEVATA - Avvio pulizia sistema...${RESET}"
    
    # Arresto e rimozione container da entrambi i nodi
    echo ""
    echo -e "${YELLOW} Pulizia container da Node1 (${NODE1_IP})...${RESET}"
    execute_remote_command "$NODE1_IP" "$VAGRANT_SSH_KEY_NODE1" \
        "docker stop $CONTAINER_NAME >/dev/null 2>&1 || true && \
         docker rm $CONTAINER_NAME >/dev/null 2>&1 || true" \
        "Container rimosso da Node1" \
        "Nessun container trovato su Node1 o errore durante la rimozione"

    echo ""
    echo -e "${YELLOW} Pulizia container da Node2 (${NODE2_IP})...${RESET}"
    execute_remote_command "$NODE2_IP" "$VAGRANT_SSH_KEY_NODE2" \
        "docker stop $CONTAINER_NAME >/dev/null 2>&1 || true && \
         docker rm $CONTAINER_NAME >/dev/null 2>&1 || true" \
        "Container rimosso da Node2" \
        "Nessun container trovato su Node2 o errore durante la rimozione"

    # Creazione del file di segnalazione per terminare gli script control.sh
    echo ""
    echo -e "${CYAN} Creazione file di segnalazione terminazione...${RESET}"
    touch "${TERMINATE_FLAG_PATH_ON_HOST}"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN} File di segnalazione creato con successo${RESET}"
    else
        echo -e "${RED} Errore nella creazione del file di segnalazione${RESET}"
    fi

    # Breve attesa per permettere agli script control.sh di rilevare il segnale
    sleep 2

    # Rimozione file temporanei locali
    echo ""
    echo -e "${CYAN} Rimozione file temporanei...${RESET}"
    rm -f "$NODE1_RAN_FILE" "$NODE2_RAN_FILE" "$TERMINATE_FLAG_PATH_ON_HOST"
    echo -e "${GREEN} File temporanei rimossi${RESET}"

    echo ""
    echo -e "${BOLD}${GREEN} PULIZIA COMPLETATA - Terminazione script${RESET}"
    exit 0
}

# Configura il trap per gestire l'interruzione Ctrl+C
trap cleanup SIGINT

# =============================================================================
# PROCESSO PRINCIPALE DI MIGRAZIONE
# =============================================================================

echo ""
echo -e "${BOLD}${MAGENTA} === AVVIO MIGRAZIONE PING-PONG DOCKER === ${RESET}"
echo ""
echo -e "${BLUE} Configurazione:${RESET}"
echo -e "${BLUE}   • Container: ${CONTAINER_IMAGE} (nome: ${CONTAINER_NAME})${RESET}"
echo -e "${BLUE}   • Porta: ${PORT_MAPPING}${RESET}"
echo -e "${BLUE}   • Intervallo migrazione: ${SLEEP_TIME} secondi${RESET}"
echo -e "${BLUE}   • Node1: ${NODE1_IP}${RESET}"
echo -e "${BLUE}   • Node2: ${NODE2_IP}${RESET}"
echo ""
echo -e "${YELLOW} Per terminare il processo, premi Ctrl+C${RESET}"

# --- Avvio Iniziale ---
# Imposta il nodo iniziale (Node1) e avvia il container
CURRENT_NODE_IP="$NODE1_IP"
CURRENT_SSH_KEY_FOR_NODE="$VAGRANT_SSH_KEY_NODE1"
CURRENT_NODE_FLAG="$NODE1_RAN_FILE"

echo ""
echo -e "${BOLD}${CYAN} Avvio iniziale container su Node1 (${NODE1_IP})${RESET}"
run_or_start_container "$CURRENT_NODE_IP" "$CURRENT_SSH_KEY_FOR_NODE" "$CURRENT_NODE_FLAG"

echo ""
echo -e "${BLUE} Attesa ${SLEEP_TIME} secondi prima della prima migrazione...${RESET}"
sleep "$SLEEP_TIME"

# --- Loop di Migrazione ---
# Ciclo infinito che alterna il container tra i due nodi
while true; do
    echo ""
    echo -e "${BOLD}${MAGENTA} === MIGRAZIONE $(date '+%Y-%m-%d %H:%M:%S') ===${RESET}"

    # Variabili per il nodo corrente (da fermare)
    NODE_TO_STOP="$CURRENT_NODE_IP"
    KEY_TO_STOP="$CURRENT_SSH_KEY_FOR_NODE"
    
    # Determina il nodo di destinazione (da avviare)
    if [ "$NODE_TO_STOP" == "$NODE1_IP" ]; then
        NODE_TO_START="$NODE2_IP"
        KEY_TO_START="$VAGRANT_SSH_KEY_NODE2"
        FLAG_TO_START="$NODE2_RAN_FILE"
        echo -e "${CYAN} Migrazione: Node1 → Node2${RESET}"
    else
        NODE_TO_START="$NODE1_IP"
        KEY_TO_START="$VAGRANT_SSH_KEY_NODE1"
        FLAG_TO_START="$NODE1_RAN_FILE"
        echo -e "${CYAN} Migrazione: Node2 → Node1${RESET}"
    fi

    # Fase 1: Arresto container sul nodo corrente
    stop_container "$NODE_TO_STOP" "$KEY_TO_STOP"

    # Fase 2: Avvio container sul nodo di destinazione  
    run_or_start_container "$NODE_TO_START" "$KEY_TO_START" "$FLAG_TO_START"

    # Aggiorna le variabili per il prossimo ciclo
    CURRENT_NODE_IP="$NODE_TO_START"
    CURRENT_SSH_KEY_FOR_NODE="$KEY_TO_START"

    # Attesa prima della prossima migrazione
    echo ""
    echo -e "${BLUE} Prossima migrazione tra ${SLEEP_TIME} secondi...${RESET}"
    echo -e "${GREEN} Container accessibile su: http://${NODE_TO_START}:${PORT_MAPPING%:*}${RESET}"
    sleep "$SLEEP_TIME"
done