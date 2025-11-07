-- CREATE
-- ==============================
-- Users (Strong Entity)
-- ==============================
CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    fname VARCHAR(50) NOT NULL,
    lname VARCHAR(50) NOT NULL,
    password_hash VARCHAR(255) NOT NULL
    -- no email or phone here, since they are multivalued
);

-- ==============================
-- User Emails (Multivalued Attribute)
-- ==============================
CREATE TABLE UserEmails (
    email_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    email VARCHAR(100) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

-- ==============================
-- User Phones (Multivalued Attribute)
-- ==============================
CREATE TABLE UserPhones (
    phone_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);
-- ==============================
-- Organizers (Strong Entity)
-- ==============================
CREATE TABLE Organizers (
    organizer_id INT AUTO_INCREMENT PRIMARY KEY,
    organization_name VARCHAR(150) NOT NULL
);
-- ==============================
-- Venues (Strong Entity)
-- ==============================
CREATE TABLE Venues (
    venue_id INT AUTO_INCREMENT PRIMARY KEY,
    venue_name VARCHAR(150) NOT NULL,
    capacity INT NOT NULL CHECK (capacity > 0),

    -- Composite attribute "Address" broken into components
    street VARCHAR(150),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    pincode VARCHAR(10),

    -- Regular attributes
    venue_phone VARCHAR(20),
    venue_email VARCHAR(100),
    owner_name VARCHAR(100)
);
-- ==============================
-- Events (Strong Entity)
-- ==============================
CREATE TABLE Events (
    event_id INT AUTO_INCREMENT PRIMARY KEY,
    event_name VARCHAR(150) NOT NULL,
    
    event_date DATE NOT NULL,
    event_time TIME NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),

    category ENUM('Concert', 'Workshop', 'Sports', 'Movie') NOT NULL,

    -- total_seats is derived (calculated from issued tickets, not stored here)

    -- Foreign keys
    organizer_id INT NOT NULL,
    venue_id INT NOT NULL,

    FOREIGN KEY (organizer_id) REFERENCES Organizers(organizer_id) ON DELETE CASCADE,
    FOREIGN KEY (venue_id) REFERENCES Venues(venue_id) ON DELETE CASCADE
);

CREATE TABLE Reservations (
    reservation_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    no_of_tickets INT NOT NULL CHECK (no_of_tickets > 0),
    status ENUM('Pending', 'Confirmed', 'Cancelled') DEFAULT 'Pending',
    cancellation_reason VARCHAR(255),
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    user_id INT NOT NULL,
    event_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (event_id) REFERENCES Events(event_id) ON DELETE CASCADE
);
-- ==============================
-- Tickets (Weak Entity)
-- ==============================
CREATE TABLE Tickets (
    ticket_id INT AUTO_INCREMENT PRIMARY KEY,
    
    ticket_category ENUM('VIP', 'EarlyBird', 'Balcony', 'Club', 'Executive') NOT NULL,
    ticket_price DECIMAL(10,2) NOT NULL CHECK (ticket_price >= 0),
    
    issue_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    ticket_status ENUM('Pending', 'Confirmed', 'Cancelled') DEFAULT 'Pending',
    
    seat_no VARCHAR(10),
    
    -- Weak entity depends on Reservation
    reservation_id INT NOT NULL,
    FOREIGN KEY (reservation_id) REFERENCES Reservations(reservation_id) ON DELETE CASCADE
);
-- ==============================
-- Booking_Modification (Strong Entity)
-- ==============================
CREATE TABLE Booking_Modification (
    modification_id INT AUTO_INCREMENT PRIMARY KEY,
    
    modification_type ENUM('Cancel', 'ChangeCategory', 'ChangeNoOfTickets', 'UpdateUserDetails') NOT NULL,
    
    modification_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    old_value VARCHAR(255),
    new_value VARCHAR(255),
    
    modification_status ENUM('Pending', 'Approved', 'Rejected') DEFAULT 'Pending',
    
    -- FK to Reservations
    reservation_id INT NOT NULL,
    FOREIGN KEY (reservation_id) REFERENCES Reservations(reservation_id) ON DELETE CASCADE
);
-- ==============================
-- Payments (Strong Entity)
-- ==============================
CREATE TABLE Payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    
    payment_status ENUM('Successful', 'Failed', 'Pending') DEFAULT 'Pending',
    payment_amount DECIMAL(10,2) NOT NULL CHECK (payment_amount >= 0),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_method ENUM('Credit', 'Debit', 'UPI') NOT NULL,
    
    -- Foreign keys
    reservation_id INT NOT NULL,
    modification_id INT,
    
    FOREIGN KEY (reservation_id) REFERENCES Reservations(reservation_id) ON DELETE CASCADE,
    FOREIGN KEY (modification_id) REFERENCES Booking_Modification(modification_id) ON DELETE SET NULL
);
-- ==============================
-- Contact (Weak Entity)
-- ==============================
CREATE TABLE Contacts (
    contact_id INT AUTO_INCREMENT PRIMARY KEY,
    
    contact_type ENUM('Email', 'Phone') NOT NULL,
    contact_value VARCHAR(100) NOT NULL,
    
    -- Weak entity depends on Organizer
    organizer_id INT NOT NULL,
    FOREIGN KEY (organizer_id) REFERENCES Organizers(organizer_id) ON DELETE CASCADE
);
-- ==============================
-- Reviews (Strong Entity)
-- ==============================
CREATE TABLE Reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comments TEXT,
    review_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign keys
    user_id INT NOT NULL,
    event_id INT NOT NULL,
    
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (event_id) REFERENCES Events(event_id) ON DELETE CASCADE
);
-- ==============================
-- Notifications (Strong Entity)
-- ==============================
CREATE TABLE Notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    
    message TEXT NOT NULL,
    notification_type ENUM(
        'ReservationUpdate',
        'PaymentUpdate',
        'ModificationUpdate',
        'RefundUpdate',
        'Alert',
        'Reminder'
    ) NOT NULL,
    
    sent_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key
    user_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);
-- ==============================
-- Refunds (Strong Entity)
-- ==============================
CREATE TABLE Refunds (
    refund_id INT AUTO_INCREMENT PRIMARY KEY,
    
    refund_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    refund_status ENUM('Pending', 'Successful', 'Failed') DEFAULT 'Pending',
    refund_amount DECIMAL(10,2) NOT NULL CHECK (refund_amount >= 0),
    
    -- Foreign keys
    reservation_id INT NOT NULL,
    payment_id INT NOT NULL,
    modification_id INT,
    
    FOREIGN KEY (reservation_id) REFERENCES Reservations(reservation_id) ON DELETE CASCADE,
    FOREIGN KEY (payment_id) REFERENCES Payments(payment_id) ON DELETE CASCADE,
    FOREIGN KEY (modification_id) REFERENCES Booking_Modification(modification_id) ON DELETE SET NULL
);

-- INSERT
INSERT INTO Users (user_id, fname, lname) VALUES
(1, 'Alice', 'Smith'),
(2, 'Bob', 'Johnson'),
(3, 'Charlie', 'Brown'),
(4, 'Diana', 'White'),
(5, 'Evan', 'Miller'),
(6, 'Fiona', 'Taylor');


INSERT INTO UserEmails (email_id, user_id, email) VALUES
(1, 1, 'alice@example.com'),
(2, 2, 'bob@example.com'),
(3, 3, 'charlie@example.com'),
(4, 4, 'diana@example.com'),
(5, 5, 'evan@example.com'),
(6, 6, 'fiona@example.com');

INSERT INTO UserPhones (phone_id, user_id, phone_number) VALUES
(1, 1, '9876543210'),
(2, 2, '8765432109'),
(3, 3, '7654321098'),
(4, 4, '6543210987'),
(5, 5, '5432109876'),
(6, 6, '4321098765');

INSERT INTO Events 
(event_name, event_date, event_time, price, category, organizer_id, venue_id) 
VALUES
('Arijit Concert', '2025-10-01', '18:00:00', 2000.00, 'Concert', 1, 1),
('Tech Expo', '2025-10-05', '10:00:00', 1500.00, 'Workshop', 4, 4),
('Cricket Match', '2025-10-10', '15:00:00', 2500.00, 'Sports', 6, 5),
('Movie Premiere', '2025-10-12', '20:00:00', 500.00, 'Movie', 5, 3),
('Startup Summit', '2025-10-15', '09:00:00', 1200.00, 'Workshop', 3, 2),
('Rock Festival', '2025-10-20', '19:00:00', 3000.00, 'Concert', 2, 6);


INSERT INTO Notifications (notification_id, message, notification_type, sent_date, user_id) VALUES
(1, 'Your reservation is confirmed.', 'Reservation', '2025-09-01', 1),
(2, 'Your payment is pending.', 'Payment', '2025-09-02', 2),
(3, 'Your booking was cancelled.', 'Modification', '2025-09-03', 3),
(4, 'Refund has been processed.', 'Refund', '2025-09-04', 4),
(5, 'Event reminder: Startup Summit.', 'Reminder', '2025-09-05', 5),
(6, 'System alert: Ticket price updated.', 'Alert', '2025-09-06', 6);

INSERT INTO Organizers (organization_name) VALUES
('Live Nation'),
('BookMyShow'),
('Eventify'),
('TechSummit Org'),
('CinemaWorld'),
('SportsHub');

INSERT INTO Venues 
(venue_name, capacity, street, city, state, country, pincode, venue_phone, venue_email, owner_name) 
VALUES
('City Arena', 5000, 'MG Road', 'Bangalore', 'Karnataka', 'India', '560001', '0801234567', 'arena@venue.com', 'Ravi Kumar'),
('Grand Hall', 2000, 'Marine Drive', 'Mumbai', 'Maharashtra', 'India', '400001', '0222345678', 'grandhall@venue.com', 'Anita Shah'),
('CineMax Theatre', 800, 'Connaught Place', 'Delhi', 'Delhi', 'India', '110001', '0118765432', 'cinemax@venue.com', 'Pooja Mehta'),
('Tech Convention Center', 1200, 'Hitech City', 'Hyderabad', 'Telangana', 'India', '500081', '0407654321', 'techcenter@venue.com', 'Suresh Reddy'),
('Sports Stadium', 3000, 'Anna Salai', 'Chennai', 'Tamil Nadu', 'India', '600001', '0443456789', 'stadium@venue.com', 'Manoj Iyer'),
('Workshop Hall', 1500, 'FC Road', 'Pune', 'Maharashtra', 'India', '411001', '0209988776', 'workshop@venue.com', 'Neha Joshi');

INSERT INTO reservations
(no_of_tickets, status, cancellation_reason, user_id, event_id)
VALUES
(2, 'Confirmed', NULL, 1, 2),
(4, 'Pending', NULL, 2, 3),
(1, 'Cancelled', 'User not available', 3, 4),
(3, 'Confirmed', NULL, 4, 5),
(5, 'Pending', NULL, 5, 6),
(2, 'Cancelled', 'Event postponed', 6, 7);

INSERT INTO tickets (ticket_category, ticket_price, ticket_status, seat_no, reservation_id)
VALUES
('VIP',        2000.00, 'Confirmed', 'A1', 1),
('EarlyBird',  1500.00, 'Pending',   'B5', 2),
('Balcony',     800.00, 'Cancelled', 'C3', 3),
('Club',       2500.00, 'Confirmed', 'D10', 4),
('Executive',  3000.00, 'Pending',   'E7', 5),
('VIP',        2200.00, 'Confirmed', 'A2', 6);

INSERT INTO Booking_Modification (modification_id, modification_type, modification_date, new_value, old_value, modification_status, reservation_id) VALUES
(1, 'Cancel', '2025-09-03', 'Cancelled', 'Confirmed', 'Approved', 3),
(2, 'Change Category', '2025-09-04', 'VIP', 'Balcony', 'Pending', 2),
(3, 'Update User Details', '2025-09-05', 'New Email', 'Old Email', 'Approved', 1),
(4, 'Change No of Tickets', '2025-09-06', '4', '2', 'Rejected', 4),
(5, 'Cancel', '2025-09-07', 'Cancelled', 'Confirmed', 'Approved', 5),
(6, 'Change Category', '2025-09-08', 'Executive', 'Club', 'Pending', 6);

INSERT INTO Payments (payment_id, payment_status, payment_amount, transaction_date, payment_method, reservation_id, modification_id) VALUES
(1, 'Successful', 6000, '2025-09-01', 'Credit', 1, NULL),
(2, 'Pending', 6000, '2025-09-02', 'UPI', 2, 2),
(3, 'Failed', 2500, '2025-09-03', 'Debit', 3, 1),
(4, 'Successful', 7500, '2025-09-04', 'Credit', 4, 4),
(5, 'Pending', 2400, '2025-09-05', 'UPI', 5, 5),
(6, 'Successful', 15000, '2025-09-06', 'Debit', 6, NULL);


INSERT INTO Contacts (contact_id, contact_type, contact_value, organizer_id) VALUES
(1, 'Email', 'livenation@mail.com', 1),
(2, 'Phone', '9876543210', 2),
(3, 'Email', 'eventify@mail.com', 3),
(4, 'Phone', '8765432109', 4),
(5, 'Email', 'cinemaworld@mail.com', 5),
(6, 'Phone', '7654321098', 6);


INSERT INTO Reviews (review_id, rating, comments, review_date, user_id, event_id) VALUES
(1, 5, 'Amazing concert!', '2025-09-02', 1, 1),
(2, 4, 'Very informative workshop.', '2025-09-06', 2, 2),
(3, 3, 'Good but too crowded.', '2025-09-10', 3, 3),
(4, 5, 'Loved the movie!', '2025-09-12', 4, 4),
(5, 4, 'Well organized event.', '2025-09-15', 5, 5),
(6, 2, 'Sound issues in concert.', '2025-09-20', 6, 6);

INSERT INTO Refunds (refund_id, refund_date, refund_status, refund_amount, reservation_id, payment_id, modification_id) VALUES
(1, '2025-09-03', 'Successful', 2500, 3, 3, 1),
(2, '2025-09-05', 'Pending', 6000, 2, 2, 2),
(3, '2025-09-06', 'Failed', 2000, 5, 5, 5),
(4, '2025-09-07', 'Successful', 7500, 4, 4, 4),
(5, '2025-09-08', 'Pending', 3000, 6, 6, 6),
(6, '2025-09-09', 'Successful', 6000, 1, 1, NULL);
