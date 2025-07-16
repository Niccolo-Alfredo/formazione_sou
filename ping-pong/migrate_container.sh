#!/bin/bash

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

# --- Dynamic Discovery of Vagrant Private Keys ---
# Trova la chiave privata per node1
VAGRANT_SSH_KEY_NODE1=$(find .vagrant/machines/node1/ -name "private_key" 2>/dev/null)
# Trova la chiave privata per node2
VAGRANT_SSH_KEY_NODE2=$(find .vagrant/machines/node2/ -name "private_key" 2>/dev/null)

if [ -z "$VAGRANT_SSH_KEY_NODE1" ]; then
    echo "Errore: Chiave SSH privata per Node 1 non trovata nel progetto."
    echo "Assicurati di eseguire lo script nella stessa directory del Vagrantfile e che le VM siano state avviate (vagrant up)."
    exit 1
fi

if [ -z "$VAGRANT_SSH_KEY_NODE2" ]; then
    echo "Errore: Chiave SSH privata per Node 2 non trovata nel progetto."
    echo "Assicurati di eseguire lo script nella stessa directory del Vagrantfile e che le VM siano state avviate (vagrant up)."
    exit 1
fi

# --- Funzioni di gestione Docker via SSH ---

# Funzione per eseguire comandi Docker su un nodo specifico
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
        echo " ${success_message}"
    else
        echo " ${error_message}"
    fi
}

# Funzione per avviare il container su un nodo specificato
run_container() {
    local node_ip=$1
    local ssh_key=$2
    echo " Tentativo di avviare il container '$CONTAINER_NAME' su $node_ip..."
    # Questo comando combina stop, rm e run in un'unica esecuzione remota
    # Utilizziamo true per non far fallire l'intero comando, dal momento che se lo stop non avviene con successo
    # si avrà un'uscita con errore. Inoltre, aggiungendo 2>/dev/null/ ignoriamo l'errore standard del primo comando.
    execute_remote_command "$node_ip" "$ssh_key" \
        "docker stop $CONTAINER_NAME 2>/dev/null || true && docker rm $CONTAINER_NAME 2>/dev/null || true && docker run -d --name $CONTAINER_NAME -p $PORT_MAPPING $CONTAINER_IMAGE" \
        "Container '$CONTAINER_NAME' avviato con successo su $node_ip." \
        "Errore nell'avvio del container '$CONTAINER_NAME' su $node_ip."
}

# Funzione per fermare e rimuovere il container su un nodo specificato
stop_container() {
    local node_ip=$1
    local ssh_key=$2
    echo " Tentativo di fermare e rimuovere il container '$CONTAINER_NAME' su $node_ip..."
    execute_remote_command "$node_ip" "$ssh_key" \
        "docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME" \
        "Container '$CONTAINER_NAME' fermato e rimosso con successo su $node_ip." \
        "Il container '$CONTAINER_NAME' non era in esecuzione o si è verificato un errore su $node_ip."
}

# Funzione di pulizia da eseguire all'uscita dello script (es. con Ctrl+C)
cleanup() {
    echo "" # Nuova riga per chiarezza nell'output
    echo "--- Rilevato segnale di interruzione (Ctrl+C). Avvio procedura di pulizia... ---"
    # Controlla se CURRENT_NODE_IP è stato impostato (cioè se un container è stato avviato almeno una volta)
    if [ -n "$CURRENT_NODE_IP" ] && [ -n "$CURRENT_SSH_KEY_FOR_NODE" ]; then
        echo " Tentativo di arrestare e rimuovere il container '$CONTAINER_NAME' dal nodo $CURRENT_NODE_IP..."
        # Usa la funzione stop_container, ma solo per il nodo *corrente* su cui dovrebbe trovarsi il container.
        execute_remote_command "$CURRENT_NODE_IP" "$CURRENT_SSH_KEY_FOR_NODE" \
            "docker stop $CONTAINER_NAME 2>/dev/null || true && docker rm $CONTAINER_NAME 2>/dev/null || true" \
            "Container '$CONTAINER_NAME' fermato e rimosso con successo da $CURRENT_NODE_IP." \
            "Il container '$CONTAINER_NAME' non era attivo su $CURRENT_NODE_IP o si è verificato un errore."
    else
        echo " Nessun container attivo noto per la pulizia o lo script non ha ancora avviato il container."
    fi
    echo "--- Pulizia completata. Uscita dallo script. ---"
    exit 0 # Esci con successo dopo la pulizia
}

# Imposta il trap: quando viene ricevuto il segnale SIGINT (da Ctrl+C), esegui la funzione cleanup.
trap cleanup SIGINT

# --- Loop di Migrazione ---

echo "--- Inizio del processo di migrazione 'ping-pong' ---"
echo "Il container '${CONTAINER_NAME}' (${CONTAINER_IMAGE}) migrerà ogni $SLEEP_TIME secondi."
echo "Sarà accessibile sulla porta ${PORT_MAPPING%:*}/TCP di uno dei due nodi."

# --- Avvio Iniziale Diretto del Container ---
# Poiché assumiamo che non ci siano container Docker in esecuzione all'avvio dello script,
# avviamo direttamente il container sul nodo iniziale designato (NODE1_IP).

CURRENT_NODE_IP="$NODE1_IP" # Inizialmente, il container sarà avviato su questo nodo.
CURRENT_SSH_KEY_FOR_NODE="$VAGRANT_SSH_KEY_NODE1" # Chiave associata al nodo iniziale.

SLEEP_TIME=10 # Tempo di attesa del ping-pong

echo ""
echo "--- Avvio iniziale del container sul nodo $CURRENT_NODE_IP (nessun Docker in esecuzione previsto) ---"
run_container "$CURRENT_NODE_IP" "$CURRENT_SSH_KEY_FOR_NODE"

echo " Attesa di $SLEEP_TIME secondi prima della prima migrazione del ciclo..."
sleep "$SLEEP_TIME"

# Primo scambio dei nodi dopo il primo avvio sul nodo 1
CURRENT_NODE_IP="$NODE1_IP" # Nodo in arresto
CURRENT_SSH_KEY_FOR_NODE="$VAGRANT_SSH_KEY_NODE1" # La chiave per il nodo in arresto

while true; do
    echo "" # Riga vuota per maggiore leggibilità
    echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"

    # Determina il prossimo nodo e la chiave SSH associata
    if [ "$CURRENT_NODE_IP" == "$NODE1_IP" ]; then
        NEXT_NODE_IP="$NODE2_IP"
        NEXT_SSH_KEY_FOR_NODE="$VAGRANT_SSH_KEY_NODE2"
    else
        NEXT_NODE_IP="$NODE1_IP"
        NEXT_SSH_KEY_FOR_NODE="$VAGRANT_SSH_KEY_NODE1"
    fi

    echo " Nodo in arresto: $CURRENT_NODE_IP, Prossimo in avvio: $NEXT_NODE_IP"

    # 1. Ferma e rimuovi il container dal nodo corrente
    stop_container "$CURRENT_NODE_IP" "$CURRENT_SSH_KEY_FOR_NODE"

    # 2. Avvia il container sul prossimo nodo
    run_container "$NEXT_NODE_IP" "$NEXT_SSH_KEY_FOR_NODE"

    # Aggiorna il nodo corrente e la sua chiave per il ciclo successivo
    CURRENT_NODE_IP="$NEXT_NODE_IP"
    CURRENT_SSH_KEY_FOR_NODE="$NEXT_SSH_KEY_FOR_NODE"

    echo " Attesa di $SLEEP_TIME secondi prima della prossima migrazione..."
    sleep "$SLEEP_TIME"
done