#!/bin/bash

# --- Colori ANSI ---
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m' # Resetta il colore al default del terminale

# --- Configurazione ---
# Indirizzi IP dei tuoi nodi Vagrant
NODE1_IP="192.168.56.101"
NODE2_IP="192.168.56.102"

# Nome dell'immagine Docker e del container
CONTAINER_IMAGE="ealen/echo-server"
CONTAINER_NAME="echo-server"

# Mappatura delle porte: Porta host:Porta container
PORT_MAPPING="8080:80"

# Utente SSH per connettersi alle VM Vagrant
SSH_USER="vagrant"

# Tempo di attesa tra le migrazioni del container (in secondi)
SLEEP_TIME=10

# --- File di Stato per i Nodi ---
# Questi file indicheranno se 'docker run' è già stato eseguito su quel nodo.
# Verranno creati nella directory temporanea del sistema.
NODE1_RAN_FILE="/tmp/${CONTAINER_NAME}_${NODE1_IP}_ran.flag"
NODE2_RAN_FILE="/tmp/${CONTAINER_NAME}_${NODE2_IP}_ran.flag"

# --- Nuovo file segnale di terminazione ---
# Questo file verrà creato nella directory condivisa di Vagrant sull'HOST.
# Nelle VM sarà accessibile tramite /vagrant/terminate_vms_flag.signal
# Assicurati che questo nome non vada in conflitto con altri file nel tuo progetto.
TERMINATE_FLAG_FILENAME="terminate_vms_flag.signal" # Solo il nome del file
TERMINATE_FLAG_PATH_ON_HOST="$(pwd)/${TERMINATE_FLAG_FILENAME}" # Percorso assoluto sull'host
TERMINATE_FLAG_PATH_ON_VM="/vagrant/${TERMINATE_FLAG_FILENAME}" # Percorso assoluto all'interno della VM

# --- Individuazione Dinamica delle Chiavi Private SSH di Vagrant ---
# Ricerca la chiave privata specifica per ogni nodo all'interno delle loro directory Vagrant.
VAGRANT_SSH_KEY_NODE1=$(find .vagrant/machines/node1/ -name "private_key" 2>/dev/null)
VAGRANT_SSH_KEY_NODE2=$(find .vagrant/machines/node2/ -name "private_key" 2>/dev/null)

# Verifiche di esistenza delle chiavi SSH
if [ -z "$VAGRANT_SSH_KEY_NODE1" ]; then
    echo -e "${RED}Errore: Chiave SSH privata per Node 1 non trovata. Assicurati che il Vagrantfile sia nella directory corrente e che le VM siano state avviate (vagrant up).${RESET}"
    exit 1
fi

if [ -z "$VAGRANT_SSH_KEY_NODE2" ]; then
    echo -e "${RED}Errore: Chiave SSH privata per Node 2 non trovata. Assicurati che il Vagrantfile sia nella directory corrente e che le VM siano state avviate (vagrant up).${RESET}"
    exit 1
fi

# --- Funzioni di gestione Docker via SSH ---

# Funzione per eseguire comandi Docker su un nodo specifico
# Questa raccoglie il comando da eseguire, il messaggio di successo o quello di errore.
execute_remote_command() {
    local node_ip=$1
    local ssh_key=$2
    local command_to_execute=$3
    local success_message=$4
    local error_message=$5

    # L'opzione -o StrictHostKeyChecking=no è usata per evitare prompt di conferma all'aggiunta di nuove chiavi host.
    # L'opzione -q per ssh rende l'output più silenzioso per i comandi remoti.
    ssh -q -i "$ssh_key" -o StrictHostKeyChecking=no "$SSH_USER"@"$node_ip" "$command_to_execute"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN} ${success_message}${RESET}"
    else
        echo -e "${RED} ${error_message}${RESET}"
    fi
}

run_or_start_container() {
    local node_ip=$1
    local ssh_key=$2
    local node_ran_flag_file=$3 # Percorso al file flag per questo nodo

    echo ""
    echo -e "${CYAN} Tentativo di avviare/riavviare il container '$CONTAINER_NAME' su $node_ip...${RESET}"

    if [ ! -f "$node_ran_flag_file" ]; then
        # Se il flag file NON esiste, significa che 'docker run' non è mai stato eseguito su questo nodo.
        # Qui usiamo 'docker stop && docker rm' per pulizia solo in caso di vecchio container rimasto.
        execute_remote_command "$node_ip" "$ssh_key" \
            "docker stop $CONTAINER_NAME > /dev/null 2>&1 || true && docker rm $CONTAINER_NAME > /dev/null 2>&1 || true && docker run -d --name $CONTAINER_NAME -p $PORT_MAPPING $CONTAINER_IMAGE > /dev/null 2>&1" \
            "Container '$CONTAINER_NAME' avviato con successo su $node_ip." \
            "Errore nell'avvio del container '$CONTAINER_NAME' su $node_ip."
        # Crea il file flag per indicare che 'docker run' è stato eseguito
        touch "$node_ran_flag_file"
    else
        # Se il flag file esiste, significa che 'docker run' è già stato eseguito in passato.
        execute_remote_command "$node_ip" "$ssh_key" \
            "docker start $CONTAINER_NAME > /dev/null 2>&1" \
            "Container '$CONTAINER_NAME' riavviato con successo su $node_ip." \
            "Errore nell'avvio del container '$CONTAINER_NAME' su $node_ip."
    fi
}

# Funzione per fermare e rimuovere il container su un nodo specificato
stop_container() {
    local node_ip=$1
    local ssh_key=$2

    echo ""
    echo -e "${YELLOW} Tentativo di fermare il container '$CONTAINER_NAME' su $node_ip...${RESET}"
    # Non usiamo docker rm qui, solo stop. Aggiungiamo || true per robustezza
    execute_remote_command "$node_ip" "$ssh_key" \
        "docker stop $CONTAINER_NAME > /dev/null 2>&1|| true" \
        "Container '$CONTAINER_NAME' fermato con successo su $node_ip." \
        "Il container '$CONTAINER_NAME' non era in esecuzione su $node_ip o si è verificato un errore durante l'arresto."
}

# Funzione di pulizia da eseguire all'uscita dello script (es. con Ctrl+C)
cleanup() {
    echo ""
    echo -e "${BOLD}${RED}--- Rilevato segnale di interruzione (Ctrl+C). Avvio procedura di pulizia... ---${RESET}"
    
    # Tentativo di fermare e rimuovere il container da ENTRAMBI i nodi
    # Usiamo execute_remote_command con comandi diretti per bypassare le funzioni stop/run modificate
    
    echo ""
    echo -e "${YELLOW} Tentativo di pulire il container '$CONTAINER_NAME' da $NODE1_IP...${RESET}"
    execute_remote_command "$NODE1_IP" "$VAGRANT_SSH_KEY_NODE1" \
        "docker stop $CONTAINER_NAME > /dev/null 2>&1 || true && docker rm $CONTAINER_NAME > /dev/null 2>&1 || true" \
        "Container '$CONTAINER_NAME' pulito con successo da $NODE1_IP." \
        "Nessun container '$CONTAINER_NAME' su $NODE1_IP o errore durante la pulizia."

    echo ""
    echo -e "${YELLOW} Tentativo di pulire il container '$CONTAINER_NAME' da $NODE2_IP...${RESET}"
    execute_remote_command "$NODE2_IP" "$VAGRANT_SSH_KEY_NODE2" \
        "docker stop $CONTAINER_NAME > /dev/null 2>&1 || true && docker rm $CONTAINER_NAME > /dev/null 2>&1|| true" \
        "Container '$CONTAINER_NAME' pulito con successo da $NODE2_IP." \
        "Nessun container '$CONTAINER_NAME' su $NODE2_IP o errore durante la pulizia."

    # --- Creazione del file segnale di terminazione sull'host ---
    # Questo file sarà nella directory di esecuzione dello script,
    # che è la directory condivisa /vagrant per le VM.
    echo ""
    touch "${TERMINATE_FLAG_PATH_ON_HOST}"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}File segnale di terminazione creato con successo.${RESET}"
    else
        echo -e "${RED}Errore nella creazione del file segnale di terminazione.${RESET}"
    fi

    sleep 2

    # Rimuovi i file di flag locali
    echo ""
    rm -f "$NODE1_RAN_FILE" "$NODE2_RAN_FILE" "$TERMINATE_FLAG_PATH_ON_HOST"
    echo -e "${GREEN}--- File di stato locali rimossi. ---${RESET}"

    echo -e "${BOLD}${RED}--- Pulizia completata. Uscita dallo script. ---${RESET}"
    exit 0 # Questo termina l'intero script.
}

# Imposta il trap: quando viene ricevuto il segnale SIGINT (da Ctrl+C), esegui la funzione cleanup.
trap cleanup SIGINT

# --- Loop di Migrazione ---

echo -e "${BOLD}${MAGENTA}--- Inizio del processo di migrazione 'ping-pong' ---${RESET}"

echo ""
echo -e "${BLUE}Il container '${CONTAINER_NAME}' (${CONTAINER_IMAGE}) migrerà ogni $SLEEP_TIME secondi.${RESET}"
echo -e "${BLUE}Sarà accessibile sulla porta ${PORT_MAPPING%:*}/TCP di uno dei due nodi.${RESET}"

# --- Avvio Iniziale Diretto del Container ---
# Poiché assumiamo che non ci siano container Docker in esecuzione all'avvio dello script,
# avviamo direttamente il container sul nodo iniziale designato (NODE1_IP) usando la nuova logica.

# Assegna i valori iniziali a CURRENT_NODE_IP e CURRENT_SSH_KEY_FOR_NODE.
# Il container sarà avviato su questo nodo per primo.
CURRENT_NODE_IP="$NODE1_IP"
CURRENT_SSH_KEY_FOR_NODE="$VAGRANT_SSH_KEY_NODE1"

echo ""
echo -e "${BOLD}${CYAN}--- Avvio iniziale del container sul nodo $CURRENT_NODE_IP (nessun Docker in esecuzione previsto) ---${RESET}"
run_or_start_container "$CURRENT_NODE_IP" "$CURRENT_SSH_KEY_FOR_NODE" "$NODE1_RAN_FILE"

echo ""
echo -e "${BLUE} Attesa di $SLEEP_TIME secondi prima della prima migrazione del ciclo...${RESET}"
sleep "$SLEEP_TIME"

while true; do
    echo "" # Riga vuota per maggiore leggibilità
    echo -e "${BOLD}${MAGENTA}--- $(date '+%Y-%m-%d %H:%M:%S') ---${RESET}"

    NODE_TO_STOP="$CURRENT_NODE_IP" # Il nodo su cui il container è attualmente in esecuzione.
    KEY_TO_STOP="$CURRENT_SSH_KEY_FOR_NODE" # La chiave per il nodo corrente.
    FLAG_TO_STOP="" # File flag per il nodo corrente.

    NODE_TO_START="" # Il nodo su cui il container verrà migrato.
    KEY_TO_START="" # La chiave per il prossimo nodo.
    FLAG_TO_START="" # File flag per il prossimo nodo.

    # Determina il prossimo nodo e la sua chiave SSH e i file flag associati.
    if [ "$NODE_TO_STOP" == "$NODE1_IP" ]; then
        NODE_TO_START="$NODE2_IP"
        KEY_TO_START="$VAGRANT_SSH_KEY_NODE2"
        FLAG_TO_STOP="$NODE1_RAN_FILE"
        FLAG_TO_START="$NODE2_RAN_FILE"
    else
        NODE_TO_START="$NODE1_IP"
        KEY_TO_START="$VAGRANT_SSH_KEY_NODE1"
        FLAG_TO_STOP="$NODE2_RAN_FILE"
        FLAG_TO_START="$NODE1_RAN_FILE"
    fi

    echo -e "${CYAN} Arresto nel nodo: $NODE_TO_STOP, Riavvio nel nodo: $NODE_TO_START${RESET}"

    # 1. Ferma il container dal nodo corrente (senza rimuoverlo)
    stop_container "$NODE_TO_STOP" "$KEY_TO_STOP"

    # 2. Riavvia il container sul prossimo nodo
    run_or_start_container "$NODE_TO_START" "$KEY_TO_START" "$FLAG_TO_START"

    # Aggiorna il nodo "corrente" per il ciclo successivo.
    CURRENT_NODE_IP="$NODE_TO_START"
    CURRENT_SSH_KEY_FOR_NODE="$KEY_TO_START"

    echo ""
    echo -e "${BLUE} Attesa di $SLEEP_TIME secondi prima della prossima migrazione...${RESET}"
    sleep "$SLEEP_TIME"
done