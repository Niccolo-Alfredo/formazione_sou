# Vagrant VM con PostgreSQL - Esempio di Database Accessibile da Host

Questo progetto è un esempio pratico che dimostra come utilizzare **Vagrant** per creare rapidamente una macchina virtuale (VM) contenente un database **PostgreSQL**. L'obiettivo è simulare un database accessibile dall'host per fini didattici o di sviluppo.

## ✅ Obiettivi del progetto

- Creare un ambiente isolato e replicabile con PostgreSQL usando Vagrant.
- Automatizzare l’installazione del database tramite provisioning shell.
- Inizializzare un database con tabelle predefinite e dati di esempio.
- Consentire l'accesso e l'interrogazione del database direttamente dalla VM o da strumenti esterni.

---

## 🧱 Struttura del progetto

```
.
├── Vagrantfile          # Configurazione della VM
├── 📖 README.md                      # Questa documentazione
└──  provision/                       # Directory di provision
        ├── install\_pg.sh        # Script di provisioning per installare e configurare PostgreSQL
        └── init\_db.sql          # Script SQL per creare e popolare il database

````

---

## 🛠️ Requisiti

- [Vagrant](https://www.vagrantup.com/downloads)
- [VirtualBox](https://www.virtualbox.org/) o altro provider Vagrant
- (Facoltativo) Un client PostgreSQL sulla macchina host

---

## 🚀 Come avviare la VM

1. Posizionati nella directory del progetto:
   ```bash
   cd nome-cartella-progetto
````

2. Avvia la macchina virtuale:

   ```bash
   vagrant up
   ```

   Questo comando:

   * Avvia una VM Ubuntu.
   * Installa PostgreSQL tramite `install_pg.sh`.
   * Crea un database chiamato `mydb` e un utente `myuser`.
   * Inizializza le tabelle `autori` e `libri` tramite `init_db.sql`.

3. Accedi alla VM:

   ```bash
   vagrant ssh
   ```

4. Accedi al database PostgreSQL:

   ```bash
   psql -U myuser -d mydb
   ```

   Oppure, per accedere come utente amministratore:

   ```bash
   sudo -u postgres psql
   ```

---

## 🧾 Descrizione del database

Lo script `init_db.sql` definisce due tabelle principali:

### Tabella `autori`

| Campo         | Tipo         | Descrizione            |
| ------------- | ------------ | ---------------------- |
| id            | SERIAL       | Identificativo univoco |
| nome          | VARCHAR(100) | Nome dell'autore       |
| cognome       | VARCHAR(100) | Cognome dell'autore    |
| data\_nascita | DATE         | Data di nascita        |
| nazione       | VARCHAR(50)  | Nazione di origine     |

### Tabella `libri`

| Campo               | Tipo         | Descrizione                              |
| ------------------- | ------------ | ---------------------------------------- |
| id                  | SERIAL       | Identificativo univoco                   |
| titolo              | VARCHAR(255) | Titolo del libro                         |
| anno\_pubblicazione | INTEGER      | Anno di pubblicazione                    |
| genere              | VARCHAR(50)  | Genere letterario                        |
| id\_autore          | INTEGER      | Collegamento all'autore (chiave esterna) |

Lo script inserisce dati di esempio relativi ad autori famosi (Orwell, Asimov, Christie, Doyle) e ai loro libri principali.

---

## 📌 Esempio di query

Una volta connesso al database, puoi eseguire query come:

```sql
SELECT titolo, anno_pubblicazione
FROM libri
WHERE genere = 'Fantascienza';
```

Oppure per vedere tutti gli autori:

```sql
SELECT * FROM autori;
```

---

## 🧹 Pulizia dell’ambiente

Per arrestare la VM:

```bash
vagrant halt
```

Per eliminarla completamente:

```bash
vagrant destroy
```

---

## ℹ️ Note

* Il provisioning è **idempotente**, quindi può essere rieseguito senza errori.
* Le tabelle vengono eliminate e ricreate ogni volta, utile per fare test puliti.
* Lo script SQL concede i permessi necessari all’utente `myuser`.

---