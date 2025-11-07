DELIMITER //

DROP PROCEDURE IF EXISTS sp_popular_events;

CREATE PROCEDURE sp_popular_events()
BEGIN
    -- This procedure returns the top 5 events based on the number of confirmed reservations (tickets).
    -- This provides the data required for the "Top Popular Events" report on the Analytics dashboard.
    SELECT 
        e.event_name, 
        SUM(r.no_of_tickets) AS total_reservations 
    FROM events e
    JOIN reservations r ON e.event_id = r.event_id
    -- Only count Confirmed reservations for accurate popularity metrics
    WHERE r.status = 'Confirmed'
    GROUP BY e.event_id, e.event_name
    ORDER BY total_reservations DESC
    LIMIT 5;
END //

DELIMITER ;



-- Stored Procedure to process a refund, update reservation status, and log the transaction
DROP PROCEDURE IF EXISTS sp_process_refund;

DELIMITER //

CREATE PROCEDURE sp_process_refund (
    IN p_reservation_id INT,
    IN p_refund_amount DECIMAL(10, 2),
    IN p_payment_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE payment_status_val VARCHAR(20);
    
    -- Start transaction block
    START TRANSACTION;
    
    -- 1. Check if the payment was successful
    SELECT payment_status INTO payment_status_val
    FROM payments
    WHERE payment_id = p_payment_id AND reservation_id = p_reservation_id;

    IF payment_status_val IS NULL OR payment_status_val != 'Successful' THEN
        SET p_success = FALSE;
        SET p_message = 'Refund rejected: Original payment was not successful or not found.';
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_message;
    ELSE
        -- 2. Update reservation status to Cancelled
        UPDATE reservations
        SET status = 'Cancelled', cancellation_reason = 'Refund processed'
        WHERE reservation_id = p_reservation_id;
        
        -- 3. Insert refund record
        INSERT INTO refunds (
            refund_date,
            refund_status,
            refund_amount,
            reservation_id,
            payment_id
        )
        VALUES (
            NOW(),
            'Successful', -- Assuming the procedure confirms the success
            p_refund_amount,
            p_reservation_id,
            p_payment_id
        );
        
        SET p_success = TRUE;
        SET p_message = CONCAT('Refund of ', p_refund_amount, ' successfully processed for reservation #', p_reservation_id);
        COMMIT;
    END IF;
    
END //

DELIMITER ;


DELIMITER //

DROP PROCEDURE IF EXISTS sp_book_reservation//

CREATE PROCEDURE sp_book_reservation(
    IN p_user_id INT,
    IN p_event_id INT,
    IN p_no_of_tickets INT,
    IN p_ticket_category VARCHAR(50),
    IN p_payment_method VARCHAR(50),
    OUT p_reservation_id INT,
    OUT p_status_message VARCHAR(255)
)
BEGIN
    DECLARE v_event_price DECIMAL(10, 2);
    DECLARE v_total_amount DECIMAL(10, 2);
    DECLARE v_venue_capacity INT;
    DECLARE v_tickets_booked INT;

    -- Transaction start to ensure all or none succeed
    START TRANSACTION;

    -- 1. Get Event and Venue Capacity Data
    SELECT
        e.price, v.capacity
    INTO
        v_event_price, v_venue_capacity
    FROM events e
    JOIN venues v ON e.venue_id = v.venue_id
    WHERE e.event_id = p_event_id;

    -- 2. Calculate Total Tickets Currently Booked (Confirmed or Pending)
    SELECT
        COALESCE(SUM(r.no_of_tickets), 0)
    INTO
        v_tickets_booked
    FROM reservations r
    WHERE r.event_id = p_event_id AND r.status IN ('Confirmed', 'Pending');

    -- 3. Perform Capacity Check (Concurrency Control)
    IF (v_tickets_booked + p_no_of_tickets) > v_venue_capacity THEN
        SET p_status_message = 'Booking failed: Event capacity exceeded.';
        SET p_reservation_id = NULL;
        ROLLBACK;
        
    ELSE -- Only proceed if capacity is sufficient
        -- 4. Calculate Total Payment Amount
        SET v_total_amount = v_event_price * p_no_of_tickets;

        -- 5. Insert Reservation Record
        INSERT INTO reservations (user_id, event_id, no_of_tickets, status)
        VALUES (p_user_id, p_event_id, p_no_of_tickets, 'Confirmed');

        -- Get the ID of the newly inserted reservation
        SET p_reservation_id = LAST_INSERT_ID();

        -- 6. Insert Ticket Record (Simplified)
        INSERT INTO tickets (reservation_id, ticket_category, ticket_price, ticket_status)
        VALUES (p_reservation_id, p_ticket_category, v_event_price, 'Confirmed');

        -- 7. Insert Payment Record
        INSERT INTO payments (reservation_id, payment_amount, payment_status, payment_method)
        VALUES (p_reservation_id, v_total_amount, 'Successful', p_payment_method);

        -- 8. Commit the entire transaction
        COMMIT;
        SET p_status_message = CONCAT('Success: Reservation ', p_reservation_id, ' confirmed.');
    END IF;

END //

DELIMITER ;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_cancel_reservation//

CREATE PROCEDURE sp_cancel_reservation(
    IN p_reservation_id INT,
    IN p_cancellation_reason VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_current_status VARCHAR(20);

    -- Check current status of the reservation, and lock the row
    SELECT status INTO v_current_status
    FROM reservations
    WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    -- Start Transaction
    START TRANSACTION;

    IF v_current_status = 'Confirmed' THEN
        -- 1. Update Reservation Status
        UPDATE reservations
        SET status = 'Cancelled',
            cancellation_reason = p_cancellation_reason
        WHERE reservation_id = p_reservation_id;
        
        -- NOTE: The trg_reservation_modification_log runs here automatically!

        -- 2. Commit changes
        COMMIT;
        SET p_success = TRUE;
        SET p_message = CONCAT('Reservation ', p_reservation_id, ' successfully cancelled.');

    ELSEIF v_current_status = 'Cancelled' THEN
        SET p_success = FALSE;
        SET p_message = 'Error: Reservation is already cancelled.';
        ROLLBACK;
    ELSE
        SET p_success = FALSE;
        SET p_message = 'Error: Cannot cancel reservation in its current state.';
        ROLLBACK;
    END IF;

END //

DELIMITER ;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_high_cancellation_events//

CREATE PROCEDURE sp_high_cancellation_events()
BEGIN
    -- This procedure identifies events where the cancellation rate exceeds 20%
    -- It uses nested logic (via the derived table 'Stats') to calculate the percentage
    -- before the final filtering.
    
    SELECT 
        e.event_name,
        (TotalCancelled * 100.0 / TotalBooked) AS CancellationRate 
        -- The rate is calculated here in the OUTER query
    FROM events e
    JOIN (
        -- *** INNER QUERY (The Subquery / Derived Table 'Stats') ***
        -- Calculates the total cancelled tickets and total tickets booked for every event_id.
        SELECT 
            event_id,
            SUM(CASE WHEN status = 'Cancelled' THEN no_of_tickets ELSE 0 END) AS TotalCancelled,
            SUM(no_of_tickets) AS TotalBooked
        FROM reservations
        GROUP BY event_id
        -- Ensure we only include events with at least one booking
        HAVING TotalBooked > 0
    ) AS Stats ON e.event_id = Stats.event_id
    -- *** OUTER QUERY FILTERING ***
    -- Filters the results set based on the calculated rate.
    WHERE (TotalCancelled * 100.0 / TotalBooked) > 20.00
    ORDER BY CancellationRate DESC;

END //

DELIMITER ;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_most_popular_venue//

CREATE PROCEDURE sp_most_popular_venue()
BEGIN
    -- This procedure returns the top 3 venues based on total confirmed tickets sold.
    -- It joins Venues, Events, and Reservations to aggregate sales by location.
    SELECT 
        v.venue_name,
        -- Sums the number of tickets confirmed in the reservation table
        COALESCE(SUM(r.no_of_tickets), 0) AS total_tickets 
    FROM venues v
    JOIN events e ON v.venue_id = e.venue_id
    LEFT JOIN reservations r ON e.event_id = r.event_id
    -- Only count confirmed sales
    WHERE r.status = 'Confirmed' OR r.status IS NULL
    GROUP BY v.venue_id, v.venue_name
    ORDER BY total_tickets DESC
    LIMIT 3;
END //

DELIMITER ;