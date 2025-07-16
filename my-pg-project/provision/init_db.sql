-- provision/init_db.sql

-- Questo script viene eseguito dal provisioner per inizializzare il database 'mydb'.
-- Verrà eseguito dall'utente 'postgres' all'interno della VM.

-- 1. Eliminazione delle tabelle esistenti (utile per test e per rendere lo script idempotente)
--    Questo evita errori se lo script viene eseguito più volte o dopo modifiche.
DROP TABLE IF EXISTS libri;
DROP TABLE IF EXISTS autori;

-- 2. Creazione della tabella 'autori'
--    Una tabella per memorizzare le informazioni sugli autori.
CREATE TABLE autori (
    id SERIAL PRIMARY KEY, -- ID univoco per ogni autore, si incrementa automaticamente
    nome VARCHAR(100) NOT NULL, -- Nome dell'autore (non può essere NULL)
    cognome VARCHAR(100) NOT NULL, -- Cognome dell'autore (non può essere NULL)
    data_nascita DATE, -- Data di nascita dell'autore (può essere NULL)
    nazione VARCHAR(50) -- Nazionalità dell'autore (può essere NULL)
);

-- 3. Creazione della tabella 'libri'
--    Una tabella per memorizzare le informazioni sui libri.
--    Include una chiave esterna (FOREIGN KEY) che si riferisce alla tabella 'autori'.
CREATE TABLE libri (
    id SERIAL PRIMARY KEY, -- ID univoco per ogni libro, si incrementa automaticamente
    titolo VARCHAR(255) NOT NULL, -- Titolo del libro (non può essere NULL)
    anno_pubblicazione INTEGER, -- Anno di pubblicazione del libro
    genere VARCHAR(50), -- Genere del libro
    id_autore INTEGER NOT NULL, -- ID dell'autore (non può essere NULL)
    FOREIGN KEY (id_autore) REFERENCES autori(id) -- Definisce la chiave esterna
);

-- 4. Inserimento di dati di esempio nella tabella 'autori'
--    Questi dati saranno presenti nel database quando la VM sarà pronta.
INSERT INTO autori (nome, cognome, data_nascita, nazione) VALUES
('George', 'Orwell', '1903-06-25', 'Inghilterra'),
('Isaac', 'Asimov', '1920-01-02', 'Russia'),
('Agatha', 'Christie', '1890-09-15', 'Inghilterra'),
('Arthur Conan', 'Doyle', '1859-05-22', 'Inghilterra');

-- 5. Inserimento di dati di esempio nella tabella 'libri'
--    Utilizziamo le subquery per recuperare gli ID degli autori, rendendo lo script più robusto
--    anche se gli ID auto-generati degli autori dovessero cambiare.
INSERT INTO libri (titolo, anno_pubblicazione, genere, id_autore) VALUES
('1984', 1949, 'Distopia', (SELECT id FROM autori WHERE nome = 'George' AND cognome = 'Orwell')),
('Fattoria degli Animali', 1945, 'Satira', (SELECT id FROM autori WHERE nome = 'George' AND cognome = 'Orwell')),
('Io, Robot', 1950, 'Fantascienza', (SELECT id FROM autori WHERE nome = 'Isaac' AND cognome = 'Asimov')),
('Il Ciclo delle Fondazioni', 1951, 'Fantascienza', (SELECT id FROM autori WHERE nome = 'Isaac' AND cognome = 'Asimov')),
('Dieci piccoli indiani', 1939, 'Giallo', (SELECT id FROM autori WHERE nome = 'Agatha' AND cognome = 'Christie')),
('Assassinio sull''Orient Express', 1934, 'Giallo', (SELECT id FROM autori WHERE nome = 'Agatha' AND cognome = 'Christie')),
('Uno studio in rosso', 1887, 'Giallo', (SELECT id FROM autori WHERE nome = 'Arthur Conan' AND cognome = 'Doyle'));

-- Concede tutti i permessi (SELECT, INSERT, UPDATE, DELETE, ecc.) sull'intera tabella 'autori' all'utente 'myuser'.
GRANT ALL PRIVILEGES ON TABLE autori TO myuser;
-- Concede l'uso della sequenza 'id' (SERIAL) associata alla tabella 'autori', necessaria per gli INSERT.
GRANT USAGE, SELECT ON SEQUENCE autori_id_seq TO myuser;

-- Concede tutti i permessi sulla tabella 'libri' all'utente 'myuser'.
GRANT ALL PRIVILEGES ON TABLE libri TO myuser;
-- Concede l'uso della sequenza 'id' (SERIAL) associata alla tabella 'libri', necessaria per gli INSERT.
GRANT USAGE, SELECT ON SEQUENCE libri_id_seq TO myuser;