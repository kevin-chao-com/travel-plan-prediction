-- ============================================================
-- 2. Create review_items
-- ============================================================

CREATE OR REPLACE TABLE review_items AS
WITH inactive_employee AS (
    SELECT
        'inactive_employee' AS category,
        'High' AS severity,
        STRING_AGG(source || ':' || record_id, ';') AS related_record_ids,
        'Travel records are linked to an inactive employee: ' || employee_id AS summary,
        'Confirm employment status, travel authorization, and whether the charges should be reassigned or investigated.' AS recommended_action,
        MAX(confidence) AS confidence
    FROM linked_records lr
    JOIN hr_employees h
        ON lr.employee_id = h.employee_id
    WHERE LOWER(h.employment_status) <> 'active'
      AND lr.trip_id <> 'NO_TRIP'
      AND lr.employee_id <> 'UNKNOWN'
    GROUP BY employee_id
),

held_itinerary AS (
    SELECT
        'missing_ticket_or_held_itinerary' AS category,
        'Medium' AS severity,
        'tmc_bookings:' || booking_id AS related_record_ids,
        'TMC booking appears held or not ticketed: ' || booking_id AS summary,
        'Confirm whether this became a real trip, was abandoned, or should be excluded from trip reporting.' AS recommended_action,
        0.85 AS confidence
    FROM tmc_bookings
    WHERE LOWER(booking_status) LIKE '%hold%'
       OR LOWER(booking_status) LIKE '%held%'
       OR LOWER(booking_status) LIKE '%not ticketed%'
),

hotel_policy AS (
    SELECT
        'hotel_rate_cap_exceeded' AS category,
        'Medium' AS severity,
        'hotel_stays:' || h.hotel_stay_id AS related_record_ids,
        'Hotel nightly rate exceeds city cap in ' || h.hotel_city AS summary,
        'Review for business justification, approved exception, conference rate, or reimbursement adjustment.' AS recommended_action,
        0.90 AS confidence
    FROM hotel_stays h
    JOIN hotel_rate_caps c
        ON LOWER(TRIM(h.hotel_city)) = LOWER(TRIM(c.city))
    WHERE h.nightly_rate_usd > c.nightly_cap_usd
),

possible_duplicate_expense AS (
    SELECT
        'possible_duplicate_expense' AS category,
        'High' AS severity,
        'card_transactions:' || c.card_txn_id || ';expense_reports:' || e.expense_line_id AS related_record_ids,
        'Card transaction and expense line have similar merchant, date, and amount.' AS summary,
        'Check whether the expense is a corporate-card reconciliation or a duplicate reimbursement request.' AS recommended_action,
        0.85 AS confidence
    FROM card_transactions c
    JOIN expense_reports e
        ON ABS(c.amount_usd - e.amount_usd) <= 1
        AND ABS(DATE_DIFF('day', c.transaction_date, e.transaction_date)) <= 3
        AND LOWER(TRIM(c.merchant_name)) = LOWER(TRIM(e.merchant_name))
),

refund_review AS (
    SELECT
        'refund_or_credit_review' AS category,
        'Medium' AS severity,
        'card_transactions:' || card_txn_id AS related_record_ids,
        'Negative card transaction may be refund, credit, exchange, or cancellation.' AS summary,
        'Match credit to original charge, exchange, cancellation, or expense adjustment.' AS recommended_action,
        0.75 AS confidence
    FROM card_transactions
    WHERE amount_usd < 0
),

possible_direct_booking AS (
    SELECT
        'possible_direct_booking' AS category,
        'Medium' AS severity,
        'card_transactions:' || lr.record_id AS related_record_ids,
        'Travel-like card transaction was not linked to a managed TMC trip.' AS summary,
        'Review whether this was an out-of-channel direct booking or should be linked to an existing trip.' AS recommended_action,
        0.70 AS confidence
    FROM linked_records lr
    JOIN card_transactions c
        ON lr.record_id = c.card_txn_id
    WHERE lr.source = 'card_transactions'
      AND lr.trip_id = 'NO_TRIP'
      AND (
            LOWER(c.merchant_category) LIKE '%air%'
         OR LOWER(c.merchant_category) LIKE '%hotel%'
         OR LOWER(c.merchant_category) LIKE '%travel%'
         OR LOWER(c.merchant_name) LIKE '%air%'
         OR LOWER(c.merchant_name) LIKE '%hotel%'
      )
),

all_items AS (
    SELECT * FROM inactive_employee
    UNION ALL
    SELECT * FROM held_itinerary
    UNION ALL
    SELECT * FROM hotel_policy
    UNION ALL
    SELECT * FROM possible_duplicate_expense
    UNION ALL
    SELECT * FROM refund_review
    UNION ALL
    SELECT * FROM possible_direct_booking
),

ranked AS (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY
                CASE severity
                    WHEN 'High' THEN 3
                    WHEN 'Medium' THEN 2
                    WHEN 'Low' THEN 1
                    ELSE 0
                END DESC,
                confidence DESC
        ) AS rank,
        category,
        severity,
        related_record_ids,
        summary,
        recommended_action,
        confidence
    FROM all_items
)

SELECT *
FROM ranked;