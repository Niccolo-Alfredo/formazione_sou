# 🐳 Docker Container Ping-Pong Migration

Un progetto che dimostra la migrazione automatica di container Docker tra due Virtual Machine per simulare la migrazione di un servizio da un nodo ad un altro in modo continuativo ogni 10 secondi.

## 📋 Descrizione

Questo progetto implementa un sistema di migrazione "ping-pong" di un container Docker tra due VM Vagrant. Il container viene alternato automaticamente tra i nodi ogni 10 secondi, consentendo di osservare in tempo reale:

- ✅ Migrazione live di servizi
- 🔄 Alternanza automatica tra nodi  
- 📊 Monitoraggio in tempo reale dello stato dei container
- 🛠️ Gestione graceful delle interruzioni

## 🏗️ Architettura

```
┌─────────────────┐    ┌─────────────────┐
│     NODE 1      │    │     NODE 2      │
│ 192.168.56.101  │    │ 192.168.56.102  │
│                 │    │                 │
│    Container    │◄──►│    Container    │
│  echo-server    │    │  echo-server    │
│  Port: 8080     │    │  Port: 8080     │
└─────────────────┘    └─────────────────┘
         ▲                       ▲
         │                       │
    ┌────────────────────────────────┐
    │     SCRIPT ORCHESTRAZIONE      │
    │   migrate_container.sh         │
    │   (Migrazione Ping-Pong)       │
    └────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisiti

- [Vagrant](https://www.vagrantup.com/) (>= 2.0)
- [VirtualBox](https://www.virtualbox.org/) (come provider Vagrant)
- Sistema operativo: Linux, macOS o Windows
- Bash shell disponibile

### Installazione e Avvio

1. **Clona o scarica il progetto**
   ```bash
   # Assicurati che tutti i file siano nella stessa directory
   ls -la
   # Dovresti vedere: Vagrantfile, orchestrate_project.sh, migrate_container.sh, control.sh e gli scripts di providing
   ```

2. **Rendi eseguibili gli script**
   ```bash
   chmod +x orchestrate_project.sh migrate_container.sh control.sh
   ```

3. **Avvia l'intero progetto**
   ```bash
   ./orchestrate_project.sh
   ```

4. **Osserva la migrazione**
   - Lo script aprirà automaticamente 2 terminali SSH per monitorare i nodi
   - Il terminale principale mostrerà il processo di migrazione
   - Il container sarà accessibile su `http://192.168.56.101:8080` o `http://192.168.56.102:8080`

5. **Interruzione del processo**
   ```
   Premi Ctrl+C nel terminale principale per fermare tutto
   ```

## 📁 Struttura del Progetto

```
docker-ping-pong/
│
├── 📄 Vagrantfile                    # Configurazione VM Vagrant
├── 🎯 orchestrate_project.sh         # Script principale di orchestrazione
├── 🔄 migrate_container.sh           # Logica di migrazione ping-pong
├── 📊 control.sh                     # Monitoraggio container nelle VM
├── 📖 README.md                      # Questa documentazione
├──  scripts/                         # Directory di provision
│       ├── node_1.sh/                # provision node 1
│       └── node_2.sh/                # provision node 2
└── .vagrant/                         # Directory generata da Vagrant
    └── machines/                     # Chiavi SSH e configurazioni VM
        ├── node1/
        └── node2/
```

## ⚙️ Componenti del Sistema

### 1. `orchestrate_project.sh` - Script Principale
**Funzione**: Coordina l'intero processo
- ✅ Avvia le VM con `vagrant up`
- 🖥️ Apre terminali SSH per il monitoraggio
- 🚀 Esegue lo script di migrazione
- 🧹 Gestisce la terminazione graceful

### 2. `migrate_container.sh` - Motore di Migrazione  
**Funzione**: Implementa la migrazione ping-pong
- 🐳 Gestisce il ciclo di vita dei container Docker
- 🔄 Alterna l'esecuzione tra Node1 e Node2
- ⏰ Migrazione automatica ogni 10 secondi
- 🛠️ Pulizia automatica all'interruzione

### 3. `control.sh` - Monitor Container
**Funzione**: Monitoraggio real-time nelle VM
- 📊 Mostra lo stato dei container Docker
- 🔍 Aggiornamento ogni secondo
- 🚪 Terminazione automatica via file di segnalazione

## 🔧 Configurazione

### Rete e IP
```bash
# In migrate_container.sh
NODE1_IP="192.168.56.101"    # IP Node1
NODE2_IP="192.168.56.102"    # IP Node2
```

### Container Docker
```bash
CONTAINER_IMAGE="ealen/echo-server"  # Immagine Docker
CONTAINER_NAME="echo-server"         # Nome container
PORT_MAPPING="8080:80"              # Porta host:container
```

### Temporizzazione
```bash
SLEEP_TIME=10  # Secondi tra le migrazioni
```

## 🎮 Utilizzo Avanzato

### Modifica dell'Intervallo di Migrazione
```bash
# Edita migrate_container.sh
SLEEP_TIME=5  # Migrazione ogni 5 secondi
```

### Test del Servizio
```bash
# Testa il servizio durante la migrazione
while true; do
  curl -s http://192.168.56.101:8080 || curl -s http://192.168.56.102:8080
  sleep 1
done
```

### Monitoraggio Manuale
```bash
# Connessione SSH manuale ai nodi
vagrant ssh node1
vagrant ssh node2

# Dentro la VM
docker ps
docker logs echo-server
```

## 📊 Cosa Osserverai

### Terminale Principale (Migrazione)
```
🚀 === AVVIO MIGRAZIONE PING-PONG DOCKER === 🚀

📋 Configurazione:
   • Container: ealen/echo-server (nome: echo-server)
   • Porta: 8080:80
   • Intervallo migrazione: 10 secondi
   • Node1: 192.168.56.101
   • Node2: 192.168.56.102

🔄 === MIGRAZIONE 2024-01-20 15:30:45 ===
📍 Migrazione: Node1 → Node2
⏸️  Arresto container 'echo-server' su 192.168.56.101...
✓ Container 'echo-server' arrestato su 192.168.56.101
⚡ Avvio container 'echo-server' su 192.168.56.102...
✓ Container 'echo-server' riavviato su 192.168.56.102
```

### Terminali SSH (Monitoraggio)
```
=== MONITORAGGIO DOCKER - node1 ===
Ultimo aggiornamento: 2024-01-20 15:30:45

Container Docker attivi:
NAMES        STATUS                    PORTS
echo-server  Up 5 seconds             0.0.0.0:8080->80/tcp
```

## 🛠️ Risoluzione Problemi

### VM non si avviano
```bash
# Controlla lo stato di Vagrant
vagrant status

# Riavvia le VM se necessario  
vagrant reload

# In caso di problemi gravi
vagrant destroy
vagrant up
```

### Problemi di connessione SSH
```bash
# Rigenera le chiavi SSH
vagrant ssh-config

# Test connessione manuale
vagrant ssh node1
```

### Container non si avviano
```bash
# Connettiti alla VM e controlla Docker
vagrant ssh node1
sudo systemctl status docker
docker version
```

### Terminali non si aprono automaticamente
**Linux**: Installa un terminale supportato
```bash
# Ubuntu/Debian
sudo apt install gnome-terminal

# CentOS/RHEL
sudo yum install gnome-terminal
```

**Windows**: Usa Git Bash e avvia manualmente
```bash
# Nel terminale Git Bash
vagrant ssh node1 -c "/vagrant/control.sh && exit"
```

## 🧹 Pulizia del Sistema

### Pulizia Automatica
Il sistema si pulisce automaticamente quando premi `Ctrl+C`:
- 🛑 Arresta tutti i container
- 🗑️ Rimuove i container da entrambi i nodi  
- 📁 Elimina i file temporanei
- 🚪 Chiude i terminali SSH

### Pulizia Manuale
```bash
# Ferma le VM
vagrant halt

# Distruggi le VM (se necessario)
vagrant destroy

# Rimuovi file temporanei
rm -f /tmp/echo-server_*_ran.flag
rm -f terminate_vms_flag.signal
```

## 🔍 File di Log e Debug

### File Temporanei
- `/tmp/echo-server_192.168.56.101_ran.flag` - Stato Node1
- `/tmp/echo-server_192.168.56.102_ran.flag` - Stato Node2  
- `terminate_vms_flag.signal` - File di terminazione

### Debug SSH
```bash
# Test connessione con debug
ssh -v -i .vagrant/machines/node1/virtualbox/private_key vagrant@192.168.56.101
```

## 🎯 Casi d'Uso

- **🏫 Didattica**: Imparare concetti di alta disponibilità
- **🧪 Testing**: Testare comportamento applicazioni durante failover
- **📊 Demo**: Dimostrare migrazione di servizi
- **🔬 Sperimentazione**: Prototipare soluzioni di disaster recovery

## 🤝 Contributi

Per miglioramenti o bug report:
1. Testa le modifiche in ambiente isolato
2. Documenta i cambiamenti nel codice
3. Assicurati che la pulizia automatica funzioni

## 📝 Licenza

Progetto open source - usa e modifica liberamente per scopi educativi e di testing.

---

**💡 Suggerimento**: Avvia il progetto con `./orchestrate_project.sh` e osserva la magia della migrazione automatica!