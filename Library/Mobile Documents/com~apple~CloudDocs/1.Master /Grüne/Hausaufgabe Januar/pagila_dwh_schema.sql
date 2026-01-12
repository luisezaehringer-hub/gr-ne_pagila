-- ============================================================================
-- Pagila Data Warehouse - Star Schema
-- ============================================================================
-- Beschreibung: Erstellt ein Star Schema DWH für DVD-Verleih-Analysen
-- Autor: Prof. Dr. Markus Grüne
-- Datum: 2025-01-29
-- Datenbank: PostgreSQL 12+
-- ============================================================================

-- Aufräumen (falls vorhanden)
DROP TABLE IF EXISTS fact_rental CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS dim_film CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS dim_store CASCADE;

-- ============================================================================
-- DIMENSIONSTABELLEN
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Dimension: Zeit (dim_date)
-- ----------------------------------------------------------------------------
-- Beschreibung: Zeitdimension mit Hierarchien: Tag → Monat → Quartal → Jahr
-- Grain: Ein Tag
-- ----------------------------------------------------------------------------

CREATE TABLE dim_date (
    date_key INTEGER PRIMARY KEY,  -- Format: YYYYMMDD (z.B. 20050524)
    full_date DATE NOT NULL,
    day_of_week VARCHAR(10),
    day_of_month INTEGER,
    day_of_year INTEGER,
    week_of_year INTEGER,
    month INTEGER,
    month_name VARCHAR(10),
    quarter VARCHAR(2),  -- Q1, Q2, Q3, Q4
    year INTEGER,
    is_weekend BOOLEAN,
    UNIQUE(full_date)
);

COMMENT ON TABLE dim_date IS 'Zeitdimension mit hierarchischen Attributen';
COMMENT ON COLUMN dim_date.date_key IS 'Surrogate Key im Format YYYYMMDD';
COMMENT ON COLUMN dim_date.quarter IS 'Quartal (Q1-Q4)';
COMMENT ON COLUMN dim_date.is_weekend IS 'TRUE wenn Samstag oder Sonntag';

-- Index für bessere Performance bei Datumsabfragen
CREATE INDEX idx_dim_date_full_date ON dim_date(full_date);
CREATE INDEX idx_dim_date_year ON dim_date(year);
CREATE INDEX idx_dim_date_quarter ON dim_date(quarter);

-- ----------------------------------------------------------------------------
-- Dimension: Film (dim_film)
-- ----------------------------------------------------------------------------
-- Beschreibung: Informationen über Filme
-- Grain: Ein Film
-- ----------------------------------------------------------------------------

CREATE TABLE dim_film (
    film_key SERIAL PRIMARY KEY,
    film_id INTEGER NOT NULL,  -- Original ID aus OLTP
    title VARCHAR(255) NOT NULL,
    description TEXT,
    release_year INTEGER,
    language VARCHAR(20),
    rental_duration INTEGER,  -- Standard-Vermietungsdauer in Tagen
    rental_rate NUMERIC(4,2),  -- Vermietungsgebühr
    length INTEGER,  -- Filmlänge in Minuten
    replacement_cost NUMERIC(5,2),
    rating VARCHAR(10),  -- G, PG, PG-13, R, NC-17
    category VARCHAR(50),  -- Action, Comedy, Drama, etc.
    special_features TEXT,
    UNIQUE(film_id)
);

COMMENT ON TABLE dim_film IS 'Filmdimension mit Kategorien und Eigenschaften';
COMMENT ON COLUMN dim_film.film_key IS 'Surrogate Key';
COMMENT ON COLUMN dim_film.film_id IS 'Business Key (aus OLTP-System)';
COMMENT ON COLUMN dim_film.category IS 'Filmkategorie für Analysen';

-- Indizes
CREATE INDEX idx_dim_film_category ON dim_film(category);
CREATE INDEX idx_dim_film_rating ON dim_film(rating);
CREATE INDEX idx_dim_film_film_id ON dim_film(film_id);

-- ----------------------------------------------------------------------------
-- Dimension: Kunde (dim_customer)
-- ----------------------------------------------------------------------------
-- Beschreibung: Kundeninformationen mit geografischer Hierarchie
-- Grain: Ein Kunde
-- Hierarchie: Kunde → Stadt → Land → Kontinent
-- ----------------------------------------------------------------------------

CREATE TABLE dim_customer (
    customer_key SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,  -- Original ID aus OLTP
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    city VARCHAR(100),
    country VARCHAR(100),
    phone VARCHAR(20),
    active BOOLEAN,  -- Ist Kunde aktiv?
    create_date DATE,
    UNIQUE(customer_id)
);

COMMENT ON TABLE dim_customer IS 'Kundendimension mit geografischen Attributen';
COMMENT ON COLUMN dim_customer.customer_key IS 'Surrogate Key';
COMMENT ON COLUMN dim_customer.active IS 'TRUE wenn Kunde aktiv ist';

-- Indizes
CREATE INDEX idx_dim_customer_country ON dim_customer(country);
CREATE INDEX idx_dim_customer_city ON dim_customer(city);
CREATE INDEX idx_dim_customer_customer_id ON dim_customer(customer_id);

-- ----------------------------------------------------------------------------
-- Dimension: Filiale (dim_store)
-- ----------------------------------------------------------------------------
-- Beschreibung: Filialen des DVD-Verleihs
-- Grain: Eine Filiale
-- ----------------------------------------------------------------------------

CREATE TABLE dim_store (
    store_key SERIAL PRIMARY KEY,
    store_id INTEGER NOT NULL,  -- Original ID aus OLTP
    manager_first_name VARCHAR(50),
    manager_last_name VARCHAR(50),
    manager_name VARCHAR(100),  -- Voller Name für Convenience
    store_address VARCHAR(100),
    store_city VARCHAR(100),
    store_country VARCHAR(100),
    store_phone VARCHAR(20),
    UNIQUE(store_id)
);

COMMENT ON TABLE dim_store IS 'Filialdimension mit Manager-Informationen';
COMMENT ON COLUMN dim_store.store_key IS 'Surrogate Key';
COMMENT ON COLUMN dim_store.manager_name IS 'Vollständiger Name des Filialleiters';

-- Indizes
CREATE INDEX idx_dim_store_city ON dim_store(store_city);
CREATE INDEX idx_dim_store_store_id ON dim_store(store_id);

-- ============================================================================
-- FAKTENTABELLE
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Faktentabelle: Vermietungen (fact_rental)
-- ----------------------------------------------------------------------------
-- Beschreibung: Jede Zeile = eine Vermietungstransaktion
-- Grain: Eine Vermietung (ein Film an einen Kunden zu einem Zeitpunkt)
-- Measures: rental_amount, days_rented, late_fees
-- ----------------------------------------------------------------------------

CREATE TABLE fact_rental (
    rental_key SERIAL PRIMARY KEY,

    -- Fremdschlüssel zu Dimensionen (Denormalisiert für Performance)
    date_key INTEGER NOT NULL REFERENCES dim_date(date_key),
    customer_key INTEGER NOT NULL REFERENCES dim_customer(customer_key),
    film_key INTEGER NOT NULL REFERENCES dim_film(film_key),
    store_key INTEGER NOT NULL REFERENCES dim_store(store_key),

    -- Degenerate Dimensions (aus OLTP, für Drill-Through)
    rental_id INTEGER,  -- Original Rental ID
    inventory_id INTEGER,  -- Welches physische Exemplar
    staff_id INTEGER,  -- Welcher Mitarbeiter

    -- Measures (Kennzahlen)
    rental_amount NUMERIC(5,2) NOT NULL,  -- Vermietungsgebühr in €
    days_rented INTEGER,  -- Tatsächliche Vermietungsdauer
    late_fees NUMERIC(5,2) DEFAULT 0,  -- Verspätungsgebühren

    -- Zeitstempel
    rental_date TIMESTAMP,
    return_date TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_rental_amount CHECK (rental_amount >= 0),
    CONSTRAINT chk_days_rented CHECK (days_rented >= 0),
    CONSTRAINT chk_late_fees CHECK (late_fees >= 0)
);

COMMENT ON TABLE fact_rental IS 'Faktentabelle: Vermietungstransaktionen';
COMMENT ON COLUMN fact_rental.rental_key IS 'Surrogate Key';
COMMENT ON COLUMN fact_rental.rental_amount IS 'Measure: Vermietungsgebühr';
COMMENT ON COLUMN fact_rental.days_rented IS 'Measure: Anzahl gemieteter Tage';
COMMENT ON COLUMN fact_rental.late_fees IS 'Measure: Verspätungsgebühren';
COMMENT ON COLUMN fact_rental.rental_id IS 'Degenerate Dimension: OLTP Rental ID';

-- Indizes für optimale Query-Performance
CREATE INDEX idx_fact_rental_date ON fact_rental(date_key);
CREATE INDEX idx_fact_rental_customer ON fact_rental(customer_key);
CREATE INDEX idx_fact_rental_film ON fact_rental(film_key);
CREATE INDEX idx_fact_rental_store ON fact_rental(store_key);

-- Composite Index für häufige Multi-Dimensional Queries
CREATE INDEX idx_fact_rental_date_customer ON fact_rental(date_key, customer_key);
CREATE INDEX idx_fact_rental_date_film ON fact_rental(date_key, film_key);

-- ============================================================================
-- VIEWS für häufige Analysen (Optional)
-- ============================================================================

-- View: Denormalisierte Faktentabelle mit allen Dimensionen (für einfache Queries)
CREATE OR REPLACE VIEW vw_rental_analysis AS
SELECT
    fr.rental_key,
    fr.rental_id,

    -- Zeit-Attribute
    dd.full_date,
    dd.day_of_week,
    dd.month,
    dd.month_name,
    dd.quarter,
    dd.year,

    -- Film-Attribute
    df.title AS film_title,
    df.category AS film_category,
    df.rating AS film_rating,
    df.length AS film_length,

    -- Kunden-Attribute
    dc.first_name || ' ' || dc.last_name AS customer_name,
    dc.city AS customer_city,
    dc.country AS customer_country,

    -- Filialen-Attribute
    ds.manager_name,
    ds.store_city,
    ds.store_country,

    -- Measures
    fr.rental_amount,
    fr.days_rented,
    fr.late_fees,
    (fr.rental_amount + fr.late_fees) AS total_revenue

FROM fact_rental fr
JOIN dim_date dd ON fr.date_key = dd.date_key
JOIN dim_film df ON fr.film_key = df.film_key
JOIN dim_customer dc ON fr.customer_key = dc.customer_key
JOIN dim_store ds ON fr.store_key = ds.store_key;

COMMENT ON VIEW vw_rental_analysis IS 'Denormalisierte View für einfache Analysen';

-- ============================================================================
-- HILFSFUNKTIONEN
-- ============================================================================

-- Funktion: Berechnet den date_key aus einem Datum
CREATE OR REPLACE FUNCTION get_date_key(p_date DATE)
RETURNS INTEGER AS $$
BEGIN
    RETURN TO_CHAR(p_date, 'YYYYMMDD')::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION get_date_key IS 'Konvertiert DATE zu date_key (YYYYMMDD)';

-- ============================================================================
-- STATISTIKEN & GRANTS
-- ============================================================================

-- Statistiken updaten für Query Optimizer
ANALYZE dim_date;
ANALYZE dim_film;
ANALYZE dim_customer;
ANALYZE dim_store;
ANALYZE fact_rental;

-- Optional: Grants für Studenten (Read-Only)
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO student_role;

-- ============================================================================
-- SCHEMA VALIDIERUNG
-- ============================================================================

-- Anzahl Tabellen ausgeben
SELECT
    'Tabellen erstellt:' AS status,
    COUNT(*) AS anzahl
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name LIKE 'dim_%' OR table_name LIKE 'fact_%';

-- Ausgabe
SELECT 'Schema erfolgreich erstellt! ✓' AS status;
