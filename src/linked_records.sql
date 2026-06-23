-- ============================================================
-- 1. Create linked_records
-- ============================================================

CREATE OR REPLACE TABLE linked_records AS
WITH hr_norm AS (
    SELECT
        employee_id,
        LOWER(TRIM(legal_name)) AS legal_name_norm,
        LOWER(TRIM(preferred_name)) AS preferred_name_norm,
        LOWER(TRIM(work_email)) AS work_email_norm,
        employment_status
    FROM hr_employees
),

tmc_anchor AS (
    SELECT
        t.booking_id,
        t.record_locator,
        'T' || LPAD(CAST(ROW_NUMBER() OVER (ORDER BY t.booking_id) AS VARCHAR), 4, '0') AS trip_id,
        COALESCE(h.employee_id, 'UNKNOWN') AS employee_id,
        CASE
            WHEN h.employee_id IS NOT NULL THEN 0.95
            ELSE 0.50
        END AS confidence,
        CASE
            WHEN h.employee_id IS NOT NULL THEN 'TMC trip anchor; employee_id/email/name matched HR'
            ELSE 'TMC trip anchor; no strong HR match'
        END AS rationale,
        t.trip_start_date,
        t.trip_end_date,
        t.destination_airport,
        t.origin_airport,
        t.booking_status
    FROM tmc_bookings t
    LEFT JOIN hr_norm h
        ON LOWER(TRIM(t.traveler_employee_id)) = LOWER(TRIM(h.employee_id))
        OR LOWER(TRIM(t.traveler_email)) = h.work_email_norm
        OR LOWER(TRIM(t.traveler_name)) = h.legal_name_norm
        OR LOWER(TRIM(t.traveler_name)) = h.preferred_name_norm
),

tmc_links AS (
    SELECT
        'tmc_bookings' AS source,
        booking_id AS record_id,
        employee_id,
        trip_id,
        confidence,
        rationale
    FROM tmc_anchor
),

flight_links AS (
    SELECT
        'flight_segments' AS source,
        f.flight_segment_id AS record_id,
        COALESCE(t.employee_id, 'UNKNOWN') AS employee_id,
        COALESCE(t.trip_id, 'NO_TRIP') AS trip_id,
        CASE
            WHEN f.booking_id = t.booking_id OR f.record_locator = t.record_locator THEN 0.95
            WHEN f.depart_date BETWEEN t.trip_start_date - INTERVAL 2 DAY
                                AND t.trip_end_date + INTERVAL 2 DAY THEN 0.70
            ELSE 0.00
        END AS confidence,
        CASE
            WHEN f.booking_id = t.booking_id THEN 'booking_id match'
            WHEN f.record_locator = t.record_locator THEN 'record_locator match'
            WHEN f.depart_date BETWEEN t.trip_start_date - INTERVAL 2 DAY
                                AND t.trip_end_date + INTERVAL 2 DAY THEN 'flight date near trip window'
            ELSE 'no reliable TMC trip match'
        END AS rationale
    FROM flight_segments f
    LEFT JOIN tmc_anchor t
        ON f.booking_id = t.booking_id
        OR f.record_locator = t.record_locator
        OR f.depart_date BETWEEN t.trip_start_date - INTERVAL 2 DAY
                            AND t.trip_end_date + INTERVAL 2 DAY
),

hotel_links AS (
    SELECT
        'hotel_stays' AS source,
        h.hotel_stay_id AS record_id,
        COALESCE(t.employee_id, 'UNKNOWN') AS employee_id,
        COALESCE(t.trip_id, 'NO_TRIP') AS trip_id,
        CASE
            WHEN h.booking_id = t.booking_id THEN 0.95
            WHEN h.check_in <= t.trip_end_date + INTERVAL 2 DAY
             AND h.check_out >= t.trip_start_date - INTERVAL 2 DAY THEN 0.70
            ELSE 0.00
        END AS confidence,
        CASE
            WHEN h.booking_id = t.booking_id THEN 'booking_id match'
            WHEN h.check_in <= t.trip_end_date + INTERVAL 2 DAY
             AND h.check_out >= t.trip_start_date - INTERVAL 2 DAY THEN 'hotel dates overlap trip window'
            ELSE 'no reliable TMC trip match'
        END AS rationale
    FROM hotel_stays h
    LEFT JOIN tmc_anchor t
        ON h.booking_id = t.booking_id
        OR (
            h.check_in <= t.trip_end_date + INTERVAL 2 DAY
            AND h.check_out >= t.trip_start_date - INTERVAL 2 DAY
        )
),

obt_links AS (
    SELECT
        'obt_searches' AS source,
        o.search_id AS record_id,
        COALESCE(t.employee_id, 'UNKNOWN') AS employee_id,
        COALESCE(t.trip_id, 'NO_TRIP') AS trip_id,
        CASE
            WHEN o.booking_ref_hint = t.record_locator THEN 0.90
            WHEN o.departure_date BETWEEN t.trip_start_date - INTERVAL 5 DAY
                                   AND t.trip_end_date + INTERVAL 5 DAY THEN 0.60
            ELSE 0.00
        END AS confidence,
        CASE
            WHEN o.booking_ref_hint = t.record_locator THEN 'booking_ref_hint matched record_locator'
            WHEN o.departure_date BETWEEN t.trip_start_date - INTERVAL 5 DAY
                                   AND t.trip_end_date + INTERVAL 5 DAY THEN 'OBT departure date near trip window'
            ELSE 'no reliable TMC trip match'
        END AS rationale
    FROM obt_searches o
    LEFT JOIN tmc_anchor t
        ON o.booking_ref_hint = t.record_locator
        OR o.departure_date BETWEEN t.trip_start_date - INTERVAL 5 DAY
                               AND t.trip_end_date + INTERVAL 5 DAY
),

card_links AS (
    SELECT
        'card_transactions' AS source,
        c.card_txn_id AS record_id,
        COALESCE(h.employee_id, 'UNKNOWN') AS employee_id,
        COALESCE(t.trip_id, 'NO_TRIP') AS trip_id,
        CASE
            WHEN t.trip_id IS NOT NULL THEN 0.70
            WHEN LOWER(c.merchant_category) LIKE '%air%'
              OR LOWER(c.merchant_category) LIKE '%hotel%'
              OR LOWER(c.merchant_category) LIKE '%travel%'
              OR LOWER(c.merchant_name) LIKE '%air%'
              OR LOWER(c.merchant_name) LIKE '%hotel%' THEN 0.40
            ELSE 0.80
        END AS confidence,
        CASE
            WHEN t.trip_id IS NOT NULL THEN 'employee and transaction date matched trip window'
            WHEN LOWER(c.merchant_category) LIKE '%air%'
              OR LOWER(c.merchant_category) LIKE '%hotel%'
              OR LOWER(c.merchant_category) LIKE '%travel%'
              OR LOWER(c.merchant_name) LIKE '%air%'
              OR LOWER(c.merchant_name) LIKE '%hotel%' THEN 'travel-like card transaction but no reliable trip match'
            ELSE 'non-travel merchant/category'
        END AS rationale
    FROM card_transactions c
    LEFT JOIN hr_norm h
        ON LOWER(TRIM(c.employee_email)) = h.work_email_norm
        OR LOWER(TRIM(c.employee_name_on_card)) = h.legal_name_norm
        OR LOWER(TRIM(c.employee_name_on_card)) = h.preferred_name_norm
    LEFT JOIN tmc_anchor t
        ON h.employee_id = t.employee_id
        AND c.transaction_date BETWEEN t.trip_start_date - INTERVAL 7 DAY
                                  AND t.trip_end_date + INTERVAL 7 DAY
),

expense_links AS (
    SELECT
        'expense_reports' AS source,
        e.expense_line_id AS record_id,
        COALESCE(h.employee_id, 'UNKNOWN') AS employee_id,
        COALESCE(t.trip_id, 'NO_TRIP') AS trip_id,
        CASE
            WHEN e.claimed_booking_ref = t.record_locator THEN 0.95
            WHEN h.employee_id = t.employee_id
             AND e.transaction_date BETWEEN t.trip_start_date - INTERVAL 7 DAY
                                      AND t.trip_end_date + INTERVAL 7 DAY THEN 0.70
            ELSE 0.35
        END AS confidence,
        CASE
            WHEN e.claimed_booking_ref = t.record_locator THEN 'claimed_booking_ref matched record_locator'
            WHEN h.employee_id = t.employee_id
             AND e.transaction_date BETWEEN t.trip_start_date - INTERVAL 7 DAY
                                      AND t.trip_end_date + INTERVAL 7 DAY THEN 'employee and transaction date matched trip window'
            ELSE 'expense identity only or no reliable trip match'
        END AS rationale
    FROM expense_reports e
    LEFT JOIN hr_norm h
        ON LOWER(TRIM(e.employee_id_reported)) = LOWER(TRIM(h.employee_id))
        OR LOWER(TRIM(e.submitter_email)) = h.work_email_norm
        OR LOWER(TRIM(e.submitter_name)) = h.legal_name_norm
        OR LOWER(TRIM(e.submitter_name)) = h.preferred_name_norm
    LEFT JOIN tmc_anchor t
        ON e.claimed_booking_ref = t.record_locator
        OR (
            h.employee_id = t.employee_id
            AND e.transaction_date BETWEEN t.trip_start_date - INTERVAL 7 DAY
                                      AND t.trip_end_date + INTERVAL 7 DAY
        )
)

SELECT * FROM tmc_links
UNION ALL
SELECT * FROM flight_links
UNION ALL
SELECT * FROM hotel_links
UNION ALL
SELECT * FROM obt_links
UNION ALL
SELECT * FROM card_links
UNION ALL
SELECT * FROM expense_links;