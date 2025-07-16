#!/bin/bash

# --- Configurazione ---
# Indirizzi IP dei tuoi nodi Vagrant
NODE1_IP="192.168.56.101"
NODE2_IP="192.168.56.102"

# Nome dell'immagine Docker e del container
CONTAINER_IMAGE="ealen/echo-server"
CONTAINER_NAME="echo-server"

# Mappatura delle porte: Porta host:Porta container
# La porta 8080 del tuo host (o del nodo Vagrant) sarà mappata alla porta 80 del container
PORT_MAPPING="8080:80"

# Utente SSH per connettersi alle VM Vagrant
SSH_USER="vagrant"

# Questo comando trova la chiave privata specifica del progetto Vagrant.
# Cerca il file 'private_key' all'interno della directory '.vagrant/machines/' del progetto corrente.
VAGRANT_SSH_KEY_NODE1=$(find .vagrant/machines/ -name "private_key" 2>/dev/null | head -n 1)
VAGRANT_SSH_KEY_NODE2=$(find .vagrant/machines/ -name "private_key" 2>/dev/null | tail -n 1)

if [ -z "$VAGRANT_SSH_KEY_NODE1" ]; then
    echo "Errore: Chiave SSH privata di node 1 non trovata nel progetto."
    echo "Assicurati di eseguire lo script nella stessa directory del Vagrantfile."
    exit 1
fi

if [ -z "$VAGRANT_SSH_KEY_NODE2" ]; then
    echo "Errore: Chiave SSH privata di Node 2 non trovata nel progetto."
    echo "Assicurati di eseguire lo script nella stessa directory del Vagrantfile."
    exit 1
fi

# Nodo iniziale su cui avviare il container
CURRENT_NODE_IP="$NODE1_IP" # Iniziamo con node1
CURRENT_SSH_KEY_NODE="$VAGRANT_SSH_KEY_NODE1"

# --- Funzioni di gestione Docker via SSH ---

# Funzione per avviare il container su un nodo specificato
run_container() {
    local node_ip=$1
    echo " Tentativo di avviare il container '$CONTAINER_NAME' su $node_ip..."
    # Prima, assicurati che il container non sia già in esecuzione o bloccato
    ssh -i "$2" -o StrictHostKeyChecking=no "$SSH_USER"@"$node_ip" "docker stop $CONTAINER_NAME 2>/dev/null || true"
    ssh -i "$2" -o StrictHostKeyChecking=no "$SSH_USER"@"$node_ip" "docker rm $CONTAINER_NAME 2>/dev/null || true"
    # Avvia il container in background (-d) e mappa le porte (-p)
    ssh -i "$2" -o StrictHostKeyChecking=no "$SSH_USER"@"$node_ip" "docker run -d --name $CONTAINER_NAME -p $PORT_MAPPING $CONTAINER_IMAGE"

    if [ $? -eq 0 ]; then
        echo " Container '$CONTAINER_NAME' avviato con successo su $node_ip."
    else
        echo " Errore nell'avvio del container '$CONTAINER_NAME' su $node_ip."
    fi
}

# Funzione per fermare e rimuovere il container su un nodo specificato
stop_container() {
    local node_ip=$1
    echo " Tentativo di fermare e rimuovere il container '$CONTAINER_NAME' su $node_ip..."
    # Ferma e rimuove il container. '|| true' evita che lo script fallisca se il container non è in esecuzione
    ssh -i "$2" -o StrictHostKeyChecking=no "$SSH_USER"@"$node_ip" "docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
    if [ $? -eq 0 ]; then
        echo " Container '$CONTAINER_NAME' fermato e rimosso con successo su $node_ip."
    else
        echo " Il container '$CONTAINER_NAME' non era in esecuzione o si è verificato un errore su $node_ip."
    fi
}

# --- Loop di Migrazione ---

echo "--- Inizio del processo di migrazione 'ping-pong' ---"
echo "Il container '${CONTAINER_NAME}' (${CONTAINER_IMAGE}) migrerà ogni 60 secondi."
echo "Sarà accessibile sulla porta ${PORT_MAPPING%:*}/TCP di uno dei due nodi."

while true; do
    echo "" # Riga vuota per maggiore leggibilità
    echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"

    # Determina il prossimo nodo per la migrazione
    if [ "$CURRENT_NODE_IP" == "$NODE1_IP" ]; then
        NEXT_NODE_IP="$NODE2_IP"
        NEXT_SSH_KEY_NODE="$VAGRANT_SSH_KEY_NODE2"
    else
        NEXT_NODE_IP="$NODE1_IP"
        NEXT_SSH_KEY_NODE="$VAGRANT_SSH_KEY_NODE1"
    fi

    echo " Nodo corrente: $CURRENT_NODE_IP, Prossimo nodo: $NEXT_NODE_IP"

    echo " Pwd chiave nodo $CURRENT_NODE_IP: $CURRENT_SSH_KEY_NODE "
    echo " Pwd chiave nodo $NEXT_NODE_IP: $NEXT_SSH_KEY_NODE "

    # 1. Ferma e rimuovi il container dal nodo corrente
    stop_container "$CURRENT_NODE_IP" "$CURRENT_SSH_KEY_NODE"

    # 2. Avvia il container sul prossimo nodo
    run_container "$NEXT_NODE_IP" "$NEXT_SSH_KEY_NODE"

    # Aggiorna il nodo corrente per il ciclo successivo
    CURRENT_NODE_IP="$NEXT_NODE_IP"
    CURRENT_SSH_KEY_NODE="$NEXT_SSH_KEY_NODE"

    echo " Attesa di 60 secondi prima della prossima migrazione..."
    sleep 60
done