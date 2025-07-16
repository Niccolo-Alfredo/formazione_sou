#!/bin/bash

echo "--- Avvio del provisioning per PostgreSQL ---"

echo "--- 1. Aggiornamento degli indici dei pacchetti ---"
sudo apt-get update -y

echo "--- 2. Installazione di PostgreSQL e dei contrib packages ---"
sudo apt-get install -y postgresql postgresql-contrib

echo "--- 3. Avvio e abilitazione del servizio PostgreSQL ---"
sudo systemctl start postgresql
sudo systemctl enable postgresql

echo "--- 4. Creazione dell'utente e del database PostgreSQL ---"

# Crea l'utente 'myuser' se non esiste.
# Questo comando può essere eseguito direttamente da psql.
# La logica "IF NOT EXISTS" è gestita direttamente nel DDL di PostgreSQL 9.5+.
sudo -u postgres psql -c "CREATE USER myuser WITH PASSWORD 'mypassword';" || echo "Utente 'myuser' esiste già, saltato."

# Crea il database 'mydb' e assegna il proprietario a 'myuser' se non esiste.
# Anche questo comando è eseguibile direttamente da psql.
sudo -u postgres psql -c "CREATE DATABASE mydb OWNER myuser;" || echo "Database 'mydb' esiste già, saltato."

echo "--- 5. Configurazione di PostgreSQL per l'accesso remoto ---"
# Modifica postgresql.conf per ascoltare su tutte le interfacce
sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/12/main/postgresql.conf

# Modifica pg_hba.conf per consentire connessioni dall'host (tramite la rete di Vagrant)
# Aggiunge una riga alla fine del file per permettere all'utente 'myuser' di connettersi al database 'mydb'
echo "host    mydb            myuser          0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/12/main/pg_hba.conf

echo "--- 6. Riavvio del servizio PostgreSQL per applicare le modifiche ---"
sudo systemctl restart postgresql

echo "--- 7. Popolamento del database 'mydb' con dati di esempio ---"
# Esegue lo script SQL situato nella directory sincronizzata.
sudo -u postgres psql -d mydb -f /tmp/provision/init_db.sql

echo "--- Provisioning di PostgreSQL completato! ---"
echo "Ora puoi connetterti alla VM con 'vagrant ssh' o da remoto dal tuo host."
echo "Per connetterti dall'host (se hai psql installato): psql -h 127.0.0.1 -p 5433 -U myuser -d mydb"
echo "La password è: mypassword"