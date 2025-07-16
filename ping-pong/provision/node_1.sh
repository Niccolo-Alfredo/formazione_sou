#!/bin/bash

echo "--- Provisioning Node1: Installazione Docker ---"

sudo apt-get update
# Aggiorna l'elenco dei pacchetti dai repository.

sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
# Installa gli strumenti essenziali per gestire i repository e scaricare file in modo sicuro.

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
# Scarica e aggiunge la chiave GPG ufficiale di Docker per la verifica dei pacchetti.

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Aggiunge il repository ufficiale di Docker alle sorgenti APT del sistema.

sudo apt-get update
# Aggiorna nuovamente l'elenco dei pacchetti per includere i pacchetti Docker appena disponibili.

sudo apt-get install -y docker-ce docker-ce-cli containerd.io
# Installa il motore Docker (Community Edition), la sua CLI e containerd.

sudo usermod -aG docker vagrant
# Aggiunge l'utente 'vagrant' al gruppo 'docker', permettendogli di eseguire i comandi Docker senza 'sudo'.

sudo systemctl enable docker
# Configura il servizio Docker per avviarsi automaticamente ogni volta che la VM si avvia.

sudo systemctl start docker
# Avvia il servizio Docker immediatamente dopo l'installazione.

echo "--- Provisioning Node1 Completato ---"