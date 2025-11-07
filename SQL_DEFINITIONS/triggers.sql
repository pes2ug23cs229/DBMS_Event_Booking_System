DELIMITER //

DROP TRIGGER IF EXISTS trg_reservation_modification_log//

CREATE TRIGGER trg_reservation_modification_log
AFTER UPDATE ON reservations
FOR EACH ROW
BEGIN
    -- Log status changes (e.g., from Confirmed to Cancelled)
    IF OLD.status != NEW.status THEN
        INSERT INTO booking_modification (
            reservation_id,
            modification_type,
            old_value,
            new_value,
            modification_status
        )
        VALUES (
            NEW.reservation_id,
            'Status Change', -- Type of modification
            OLD.status,
            NEW.status,
            'Approved'
        );
    END IF;

    -- Log changes in number of tickets
    IF OLD.no_of_tickets != NEW.no_of_tickets THEN
        INSERT INTO booking_modification (
            reservation_id,
            modification_type,
            old_value,
            new_value,
            modification_status
        )
        VALUES (
            NEW.reservation_id,
            'ChangeNoOfTickets',
            CAST(OLD.no_of_tickets AS CHAR),
            CAST(NEW.no_of_tickets AS CHAR),
            'Approved'
        );
    END IF;
END //

DELIMITER ;

DELIMITER //

DROP TRIGGER IF EXISTS trg_payment_after_insert//

CREATE TRIGGER trg_payment_after_insert
AFTER INSERT ON payments -- Fired AFTER a new row is INSERTED into the payments table
FOR EACH ROW
BEGIN
    -- Action: Update the corresponding reservation's status to Confirmed
    IF NEW.payment_status = 'Successful' THEN
        UPDATE reservations
        SET status = 'Confirmed'
        WHERE reservation_id = NEW.reservation_id;
    END IF;
END$$

DELIMITER ;

DROP VIEW IF EXISTS vw_event_revenue;

CREATE VIEW vw_event_revenue AS
SELECT 
    e.event_name,
    COALESCE(SUM(p.payment_amount), 0.00) AS total_revenue
FROM events e
JOIN reservations r ON e.event_id = r.event_id
JOIN payments p ON r.reservation_id = p.reservation_id
WHERE p.payment_status = 'Successful' -- Only count successful revenue
GROUP BY e.event_id, e.event_name;
