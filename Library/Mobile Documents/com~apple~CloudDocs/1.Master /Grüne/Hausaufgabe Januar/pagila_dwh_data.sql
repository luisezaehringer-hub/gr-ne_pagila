-- ============================================================================
-- Pagila Data Warehouse - Beispieldaten (ETL)
-- ============================================================================
-- Beschreibung: Befüllt das Star Schema DWH mit realistischen Beispieldaten
-- Autor: Prof. Dr. Markus Grüne
-- Datum: 2025-01-29
-- Hinweis: Dieses Skript generiert synthetische Daten für Lernzwecke
-- ============================================================================

-- Warnun ausgeben
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Pagila DWH - Daten werden geladen...';
    RAISE NOTICE 'Geschätzte Dauer: 10-30 Sekunden';
    RAISE NOTICE '================================================';
END $$;

-- ============================================================================
-- 1. ZEITDIMENSION BEFÜLLEN (dim_date)
-- ============================================================================
-- Generiert Tage von 2005-01-01 bis 2006-12-31

TRUNCATE TABLE dim_date CASCADE;

INSERT INTO dim_date (
    date_key, full_date, day_of_week, day_of_month, day_of_year,
    week_of_year, month, month_name, quarter, year, is_weekend
)
SELECT
    TO_CHAR(datum, 'YYYYMMDD')::INTEGER AS date_key,
    datum AS full_date,
    TO_CHAR(datum, 'Day') AS day_of_week,
    EXTRACT(DAY FROM datum)::INTEGER AS day_of_month,
    EXTRACT(DOY FROM datum)::INTEGER AS day_of_year,
    EXTRACT(WEEK FROM datum)::INTEGER AS week_of_year,
    EXTRACT(MONTH FROM datum)::INTEGER AS month,
    TO_CHAR(datum, 'Month') AS month_name,
    'Q' || EXTRACT(QUARTER FROM datum) AS quarter,
    EXTRACT(YEAR FROM datum)::INTEGER AS year,
    CASE WHEN EXTRACT(ISODOW FROM datum) IN (6,7) THEN TRUE ELSE FALSE END AS is_weekend
FROM generate_series(
    '2005-01-01'::DATE,
    '2006-12-31'::DATE,
    '1 day'::INTERVAL
) AS datum;

SELECT 'dim_date geladen: ' || COUNT(*) || ' Tage' FROM dim_date;

-- ============================================================================
-- 2. FILMDIMENSION BEFÜLLEN (dim_film)
-- ============================================================================

TRUNCATE TABLE dim_film CASCADE;

-- Kategorien für Filme
DO $$
DECLARE
    categories TEXT[] := ARRAY['Action', 'Comedy', 'Drama', 'Horror', 'Sci-Fi',
                               'Documentary', 'Animation', 'Romance', 'Thriller', 'Family',
                               'Fantasy', 'Crime', 'Adventure', 'Mystery', 'Musical'];
    ratings TEXT[] := ARRAY['G', 'PG', 'PG-13', 'R', 'NC-17'];
    languages TEXT[] := ARRAY['English', 'German', 'French', 'Spanish', 'Italian'];
    i INTEGER;
    random_category TEXT;
    random_rating TEXT;
    random_language TEXT;
BEGIN
    FOR i IN 1..1000 LOOP
        random_category := categories[1 + floor(random() * array_length(categories, 1))];
        random_rating := ratings[1 + floor(random() * array_length(ratings, 1))];
        random_language := languages[1 + floor(random() * array_length(languages, 1))];

        INSERT INTO dim_film (
            film_id, title, description, release_year, language,
            rental_duration, rental_rate, length, replacement_cost,
            rating, category, special_features
        ) VALUES (
            i,
            'FILM ' || LPAD(i::TEXT, 4, '0'),
            'A ' || random_category || ' film about adventure and excitement.',
            2000 + floor(random() * 24)::INTEGER,  -- 2000-2023
            random_language,
            3 + floor(random() * 5)::INTEGER,  -- 3-7 Tage
            0.99 + (floor(random() * 5) * 0.99),  -- 0.99, 1.98, 2.97, 3.96, 4.95
            60 + floor(random() * 120)::INTEGER,  -- 60-180 Minuten
            10.00 + (random() * 20)::NUMERIC(5,2),
            random_rating,
            random_category,
            CASE WHEN random() < 0.3 THEN 'Behind Scenes,Deleted Scenes' ELSE NULL END
        );
    END LOOP;
END $$;

SELECT 'dim_film geladen: ' || COUNT(*) || ' Filme' FROM dim_film;

-- ============================================================================
-- 3. KUNDENDIMENSION BEFÜLLEN (dim_customer)
-- ============================================================================

TRUNCATE TABLE dim_customer CASCADE;

DO $$
DECLARE
    first_names TEXT[] := ARRAY['Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael',
                                'Linda', 'William', 'Barbara', 'David', 'Elizabeth', 'James',
                                'Susan', 'Richard', 'Jessica', 'Joseph', 'Sarah', 'Thomas'];
    last_names TEXT[] := ARRAY['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia',
                               'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Wilson', 'Anderson'];
    cities TEXT[] := ARRAY['Berlin', 'Munich', 'Hamburg', 'Cologne', 'Frankfurt',
                           'Stuttgart', 'Düsseldorf', 'Leipzig', 'Dresden', 'Hannover',
                           'Paris', 'Lyon', 'London', 'Manchester', 'Rome', 'Milan',
                           'Madrid', 'Barcelona', 'Vienna', 'Zurich'];
    countries TEXT[] := ARRAY['Germany', 'Germany', 'Germany', 'Germany', 'Germany',
                              'Germany', 'Germany', 'Germany', 'Germany', 'Germany',
                              'France', 'France', 'United Kingdom', 'United Kingdom',
                              'Italy', 'Italy', 'Spain', 'Spain', 'Austria', 'Switzerland'];
    i INTEGER;
    fname TEXT;
    lname TEXT;
    city TEXT;
    country TEXT;
    city_idx INTEGER;
BEGIN
    FOR i IN 1..600 LOOP
        fname := first_names[1 + floor(random() * array_length(first_names, 1))];
        lname := last_names[1 + floor(random() * array_length(last_names, 1))];
        city_idx := 1 + floor(random() * array_length(cities, 1));
        city := cities[city_idx];
        country := countries[city_idx];

        INSERT INTO dim_customer (
            customer_id, first_name, last_name, email, city, country,
            phone, active, create_date
        ) VALUES (
            i,
            fname,
            lname,
            LOWER(fname || '.' || lname || '@example.com'),
            city,
            country,
            '+49' || LPAD((1000000000 + floor(random() * 9000000000))::BIGINT::TEXT, 10, '0'),
            random() < 0.95,  -- 95% aktive Kunden
            '2004-01-01'::DATE + (random() * 365)::INTEGER
        );
    END LOOP;
END $$;

SELECT 'dim_customer geladen: ' || COUNT(*) || ' Kunden' FROM dim_customer;

-- ============================================================================
-- 4. FILIALDIMENSION BEFÜLLEN (dim_store)
-- ============================================================================

TRUNCATE TABLE dim_store CASCADE;

INSERT INTO dim_store (
    store_id, manager_first_name, manager_last_name, manager_name,
    store_address, store_city, store_country, store_phone
) VALUES
    (1, 'Mike', 'Hillyer', 'Mike Hillyer', '123 Main St', 'Lethbridge', 'Canada', '+1-403-555-0001'),
    (2, 'Jon', 'Stephens', 'Jon Stephens', '456 Oak Ave', 'Woodridge', 'Australia', '+61-2-555-0002');

SELECT 'dim_store geladen: ' || COUNT(*) || ' Filialen' FROM dim_store;

-- ============================================================================
-- 5. FAKTENTABELLE BEFÜLLEN (fact_rental)
-- ============================================================================

TRUNCATE TABLE fact_rental CASCADE;

DO $$
DECLARE
    rental_count INTEGER := 16000;  -- Anzahl zu generierender Vermietungen
    i INTEGER;
    random_date DATE;
    random_date_key INTEGER;
    random_customer_key INTEGER;
    random_film_key INTEGER;
    random_store_key INTEGER;
    base_rental_rate NUMERIC(5,2);
    calculated_days INTEGER;
    calculated_late_fees NUMERIC(5,2);
    return_date_calc DATE;
BEGIN
    FOR i IN 1..rental_count LOOP
        -- Zufälliges Datum zwischen Mai 2005 und August 2006
        random_date := '2005-05-01'::DATE + (random() * 450)::INTEGER;
        random_date_key := TO_CHAR(random_date, 'YYYYMMDD')::INTEGER;

        -- Zufällige Dimensions-Keys
        random_customer_key := 1 + floor(random() * 600)::INTEGER;
        random_film_key := 1 + floor(random() * 1000)::INTEGER;
        random_store_key := 1 + floor(random() * 2)::INTEGER;

        -- Rental Rate vom Film abholen
        SELECT rental_rate INTO base_rental_rate
        FROM dim_film
        WHERE film_key = random_film_key;

        -- Vermietungsdauer: 1-10 Tage
        calculated_days := 1 + floor(random() * 10)::INTEGER;

        -- Return Date berechnen
        return_date_calc := random_date + calculated_days;

        -- Late Fees: 20% Chance auf Verspätung
        IF random() < 0.2 THEN
            calculated_late_fees := (1 + floor(random() * 3)) * 0.99;
        ELSE
            calculated_late_fees := 0;
        END IF;

        INSERT INTO fact_rental (
            rental_id, date_key, customer_key, film_key, store_key,
            inventory_id, staff_id,
            rental_amount, days_rented, late_fees,
            rental_date, return_date
        ) VALUES (
            i,
            random_date_key,
            random_customer_key,
            random_film_key,
            random_store_key,
            1 + floor(random() * 5000)::INTEGER,
            1 + floor(random() * 10)::INTEGER,
            base_rental_rate,
            calculated_days,
            calculated_late_fees,
            random_date + (random() * 86400)::INTEGER * INTERVAL '1 second',  -- Zufällige Uhrzeit
            return_date_calc + (random() * 86400)::INTEGER * INTERVAL '1 second'
        );

        -- Progress-Anzeige alle 2000 Zeilen
        IF i % 2000 = 0 THEN
            RAISE NOTICE 'Fortschritt: % / % Vermietungen geladen', i, rental_count;
        END IF;
    END LOOP;
END $$;

SELECT 'fact_rental geladen: ' || COUNT(*) || ' Vermietungen' FROM fact_rental;

-- ============================================================================
-- 6. STATISTIKEN AKTUALISIEREN
-- ============================================================================

ANALYZE dim_date;
ANALYZE dim_film;
ANALYZE dim_customer;
ANALYZE dim_store;
ANALYZE fact_rental;

-- ============================================================================
-- 7. VALIDIERUNG
-- ============================================================================

-- Zusammenfassung ausgeben
DO $$
DECLARE
    cnt_date INTEGER;
    cnt_film INTEGER;
    cnt_customer INTEGER;
    cnt_store INTEGER;
    cnt_rental INTEGER;
    total_revenue NUMERIC(10,2);
BEGIN
    SELECT COUNT(*) INTO cnt_date FROM dim_date;
    SELECT COUNT(*) INTO cnt_film FROM dim_film;
    SELECT COUNT(*) INTO cnt_customer FROM dim_customer;
    SELECT COUNT(*) INTO cnt_store FROM dim_store;
    SELECT COUNT(*) INTO cnt_rental FROM fact_rental;
    SELECT SUM(rental_amount + late_fees) INTO total_revenue FROM fact_rental;

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Pagila DWH - Daten erfolgreich geladen! ✓';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Dimensionen:';
    RAISE NOTICE '  - Zeit:      % Tage', cnt_date;
    RAISE NOTICE '  - Filme:     % Filme', cnt_film;
    RAISE NOTICE '  - Kunden:    % Kunden', cnt_customer;
    RAISE NOTICE '  - Filialen:  % Filialen', cnt_store;
    RAISE NOTICE '';
    RAISE NOTICE 'Fakten:';
    RAISE NOTICE '  - Vermietungen: %', cnt_rental;
    RAISE NOTICE '  - Gesamtumsatz: € %', total_revenue;
    RAISE NOTICE '================================================';
END $$;

-- Test-Query: Top 5 Kategorien nach Umsatz
SELECT
    'Top 5 Kategorien:' AS info,
    category,
    TO_CHAR(SUM(rental_amount), '999,999.99') AS revenue
FROM fact_rental fr
JOIN dim_film df ON fr.film_key = df.film_key
GROUP BY category
ORDER BY SUM(rental_amount) DESC
LIMIT 5;

-- Ausgabe
SELECT '✓ Datenladevorgang abgeschlossen!' AS status;
