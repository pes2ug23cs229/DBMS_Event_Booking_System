DELIMITER //

DROP FUNCTION IF EXISTS get_event_average_rating//

CREATE FUNCTION get_event_average_rating (p_event_id INT)
RETURNS DECIMAL(3, 2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE avg_rating DECIMAL(3, 2);

    -- Calculates the average rating for the given event ID
    SELECT AVG(rating) INTO avg_rating
    FROM reviews
    WHERE event_id = p_event_id;

    -- Returns 0.00 if no reviews exist (instead of NULL), ensuring clean display on the dashboard
    RETURN IFNULL(avg_rating, 0.00);
END$$

DELIMITER ;

DELIMITER //

DROP FUNCTION IF EXISTS fn_event_revenue//

CREATE FUNCTION fn_event_revenue (p_event_id INT)
RETURNS DECIMAL(10, 2)
READS SQL DATA
BEGIN
    DECLARE v_event_revenue DECIMAL(10, 2);

    -- Calculates the total revenue for the specified event by joining reservations and payments
    SELECT 
        COALESCE(SUM(p.payment_amount), 0.00)
    INTO 
        v_event_revenue
    FROM events e
    JOIN reservations r ON e.event_id = r.event_id
    JOIN payments p ON r.reservation_id = p.reservation_id
    WHERE e.event_id = p_event_id 
      AND p.payment_status = 'Successful';

    -- Returns 0.00 if no successful payments are found for the event
    RETURN v_event_revenue;
END$$

DELIMITER ;

DELIMITER //

DROP FUNCTION IF EXISTS fn_user_spending//

CREATE FUNCTION fn_user_spending (p_user_id INT)
RETURNS DECIMAL(10, 2)
READS SQL DATA
BEGIN
    DECLARE v_total_spending DECIMAL(10, 2);

    -- Calculates the sum of payments for a specific user ID
    SELECT 
        COALESCE(SUM(p.payment_amount), 0.00)
    INTO 
        v_total_spending
    FROM payments p
    JOIN reservations r ON p.reservation_id = r.reservation_id
    WHERE r.user_id = p_user_id 
      AND p.payment_status = 'Successful';

    -- Returns 0.00 if the user has no successful payments
    RETURN v_total_spending;
END$$

DELIMITER ;

DELIMITER //

DROP FUNCTION IF EXISTS calculate_total_revenue //

CREATE FUNCTION calculate_total_revenue()
RETURNS DECIMAL(10, 2)
READS SQL DATA
BEGIN
    DECLARE v_total_revenue DECIMAL(10, 2);

    -- Sums the payment amount from all successful payments in the system
    SELECT 
        COALESCE(SUM(p.payment_amount), 0.00)
    INTO 
        v_total_revenue
    FROM payments p
    WHERE p.payment_status = 'Successful';

    RETURN v_total_revenue;
END //

DELIMITER ;

DELIMITER //

DROP FUNCTION IF EXISTS fn_avg_ticket_price//

CREATE FUNCTION fn_avg_ticket_price()
RETURNS DECIMAL(10, 2)
READS SQL DATA
BEGIN
    DECLARE v_avg_price DECIMAL(10, 2);

    -- Calculate average price for events whose date is in the future (or today)
    SELECT 
        COALESCE(AVG(price), 0.00)
    INTO 
        v_avg_price
    FROM events
    WHERE event_date >= CURDATE(); 

    RETURN v_avg_price;
END //

DELIMITER ;

