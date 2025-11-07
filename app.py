# app.py 
from flask import Flask, render_template, request, redirect, url_for, jsonify
import mysql.connector
from mysql.connector import errorcode
import json
import logging

# Set up logging for debugging
logging.basicConfig(level=logging.DEBUG)

app = Flask(__name__)


DB_CONFIG = {
    'user': 'root',        
    'password': 'qwerty', 
    'host': 'localhost',
    'database': 'event_booking_system',
}

# ENUM data used in dropdowns (from DB schema)
EVENT_CATEGORIES = ['Concert', 'Workshop', 'Sports', 'Movie']
TICKET_CATEGORIES = ['VIP', 'EarlyBird', 'Balcony', 'Club', 'Executive']
PAYMENT_METHODS = ['Credit', 'Debit', 'UPI']

# Helper function to establish database connection
def get_db_connection():
    try:
        cnx = mysql.connector.connect(**DB_CONFIG)
        return cnx
    except mysql.connector.Error as err:
        logging.error(f"Database connection error: {err}")
        return None

# Helper function to execute a query (used for INSERT/UPDATE/DELETE)
def db_execute(query, params=None):
    cnx = get_db_connection()
    if cnx is None:
        return False
    try:
        cursor = cnx.cursor()
        cursor.execute(query, params or ())
        cnx.commit()
        return True
    except mysql.connector.Error as err:
        logging.error(f"SQL Execution Error: {err} for query: {query} with params: {params}")
        return False
    finally:
        if cnx.is_connected():
            cursor.close()
            cnx.close()

# Data Fetching Helpers 

def fetch_all_venues():
    cnx = get_db_connection()
    if cnx is None: return []
    try:
        cursor = cnx.cursor(dictionary=True)
        cursor.execute("SELECT venue_id, venue_name, capacity FROM venues")
        return cursor.fetchall()
    except mysql.connector.Error as err:
        logging.error(f"Error fetching venues: {err}")
        return []
    finally:
        if cnx.is_connected(): cnx.close()

def fetch_all_organizers():
    cnx = get_db_connection()
    if cnx is None: return []
    try:
        cursor = cnx.cursor(dictionary=True)
        cursor.execute("SELECT organizer_id, organization_name FROM organizers")
        return cursor.fetchall()
    except mysql.connector.Error as err:
        logging.error(f"Error fetching organizers: {err}")
        return []
    finally:
        if cnx.is_connected(): cnx.close()

def fetch_all_events():
    # Includes JOIN to get venue and organizer names for display
    query = """
    SELECT
        e.event_id, e.event_name, DATE_FORMAT(e.event_date, '%Y-%m-%d') AS event_date,
        TIME_FORMAT(e.event_time, '%H:%i') AS event_time, e.price, e.category,
        v.venue_name, v.capacity, o.organization_name
    FROM events e
    JOIN venues v ON e.venue_id = v.venue_id
    JOIN organizers o ON e.organizer_id = o.organizer_id;
    """
    cnx = get_db_connection()
    if cnx is None: return []
    try:
        cursor = cnx.cursor(dictionary=True)
        cursor.execute(query)
        return cursor.fetchall()
    except mysql.connector.Error as err:
        logging.error(f"Error fetching events: {err}")
        return []
    finally:
        if cnx.is_connected(): cnx.close()

def fetch_user_reservations(user_id):
    # Fetch user reservations with event details
    query = """
    SELECT
        r.reservation_id, r.no_of_tickets, r.status, r.booking_date,
        e.event_name, e.price, e.event_id
    FROM reservations r
    JOIN events e ON r.event_id = e.event_id
    WHERE r.user_id = %s
    ORDER BY r.booking_date DESC;
    """
    cnx = get_db_connection()
    if cnx is None: return []
    try:
        cursor = cnx.cursor(dictionary=True)
        cursor.execute(query, (user_id,))
        return cursor.fetchall()
    except mysql.connector.Error as err:
        logging.error(f"Error fetching reservations for user {user_id}: {err}")
        return []
    finally:
        if cnx.is_connected(): cnx.close()

def fetch_user_notifications(user_id):
    # Fetch user-specific notifications
    query = """
    SELECT notification_id, message, notification_type, sent_date
    FROM notifications
    WHERE user_id = %s
    ORDER BY sent_date DESC;
    """
    cnx = get_db_connection()
    if cnx is None: return []
    try:
        cursor = cnx.cursor(dictionary=True)
        cursor.execute(query, (user_id,))
        return cursor.fetchall()
    except mysql.connector.Error as err:
        logging.error(f"Error fetching notifications for user {user_id}: {err}")
        return []
    finally:
        if cnx.is_connected(): cnx.close()

# Analytics Fetching Logic 

def fetch_analytics_data():
    cnx = get_db_connection()
    if cnx is None:
        return {}
    try:
        cursor = cnx.cursor(dictionary=True)

        # KPI 1: Total Revenue (Calling renamed custom function: calculate_total_revenue)
        cursor.execute("SELECT calculate_total_revenue() AS total_revenue;")
        total_revenue = cursor.fetchone()['total_revenue']

        # KPI 2: Average Ticket Price (Calling a function)
        cursor.execute("SELECT fn_avg_ticket_price() AS avg_price;")
        avg_price = cursor.fetchone()['avg_price']

        # Report 1: Event Revenue Report (Using View)
        cursor.execute("SELECT event_name, total_revenue FROM vw_event_revenue ORDER BY total_revenue DESC;")
        event_revenue_report = cursor.fetchall()

        # Report 2: Most Popular Venue Report (Calling procedure)
        cursor.callproc('sp_most_popular_venue')
        for result in cursor.stored_results():
            popular_venues = result.fetchall()

        # Report 3: High Cancellation Events (Calling procedure)
        cursor.callproc('sp_high_cancellation_events')
        for result in cursor.stored_results():
            cancellation_report = result.fetchall()

        # Report 4: Popular Events (Calling existing procedure)
        cursor.callproc('sp_popular_events')
        for result in cursor.stored_results():
            popular_events = result.fetchall()

        # Report 5: Event Rating Report (Calling  function for each event)
        ratings_report = []
        for event in fetch_all_events():
            cursor.execute("SELECT get_event_average_rating(%s) AS avg_rating;", (event['event_id'],))
            avg_rating_result = cursor.fetchone()
            ratings_report.append({
                'event_name': event['event_name'],
                'avg_rating': f"{avg_rating_result['avg_rating']:.2f}" if avg_rating_result['avg_rating'] is not None else 'N/A'
            })


        return {
            'total_revenue': f"{total_revenue:,.2f}" if total_revenue is not None else '0.00',
            'avg_price': f"{avg_price:,.2f}" if avg_price is not None else '0.00',
            'event_revenue_report': event_revenue_report,
            'popular_venues': popular_venues,
            'cancellation_report': cancellation_report,
            'ratings_report': ratings_report,
            'popular_events': popular_events
        }

    except mysql.connector.Error as err:
        logging.error(f"Error executing analytics procedure: {err}")
        return {}
    finally:
        if cnx.is_connected(): cnx.close()

# Flask Routes 

@app.route('/')
def index():
    # 1. Fetch dropdown lists for forms
    venues = fetch_all_venues()
    organizers = fetch_all_organizers()

    # 2. Fetch User-specific data 
    # NOTE: Change user_id here to test different users!
    user_id = 2
    reservations = fetch_user_reservations(user_id)
    notifications = fetch_user_notifications(user_id)

    # 3. Fetch all active events and analytics data
    events = fetch_all_events()
    analytics_data = fetch_analytics_data()

    # Pass all data to the template
    return render_template('index.html',
                           events=events,
                           venues=venues,
                           organizers=organizers,
                           categories=EVENT_CATEGORIES,
                           ticket_categories=TICKET_CATEGORIES,
                           payment_methods=PAYMENT_METHODS,
                           reservations=reservations,
                           notifications=notifications,
                           analytics=analytics_data,
                           current_user_id=user_id)

# CRUD ROUTES 

@app.route('/save_event', methods=['POST'])
def save_event():
    event_id = request.form.get('event_id')
    event_name = request.form['event_name']
    event_date = request.form['event_date']
    event_time = request.form['event_time']
    price = request.form['price']
    category = request.form['category']
    organizer_id = request.form['organizer_id']
    venue_id = request.form['venue_id']

    if event_id:
        # UPDATE operation
        query = """
        UPDATE events SET event_name=%s, event_date=%s, event_time=%s, price=%s,
        category=%s, organizer_id=%s, venue_id=%s WHERE event_id=%s
        """
        params = (event_name, event_date, event_time, price, category, organizer_id, venue_id, event_id)
        db_execute(query, params)
    else:
        # CREATE operation
        query = """
        INSERT INTO events (event_name, event_date, event_time, price, category, organizer_id, venue_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        params = (event_name, event_date, event_time, price, category, organizer_id, venue_id)
        db_execute(query, params)

    return redirect(url_for('index'))

@app.route('/delete_event/<int:event_id>', methods=['POST'])
def delete_event(event_id):
    query = "DELETE FROM events WHERE event_id = %s"
    db_execute(query, (event_id,))
    return redirect(url_for('index'))

# TRANSACTIONAL ROUTES (Calling Procedures) 

@app.route('/book_event', methods=['POST'])
def book_event():
    # Fix: Use request.get_json() for AJAX submission
    data = request.get_json()
    if not data:
        return jsonify({'success': False, 'message': 'Invalid request format.'}), 400

    # Hardcoded user ID for demonstration
    current_user_id = 2
    
    event_id = data.get('event_id')
    no_of_tickets = data.get('no_of_tickets')
    ticket_category = data.get('ticket_category')
    payment_method = data.get('payment_method')

    if not event_id or not no_of_tickets or not ticket_category or not payment_method:
        return jsonify({'success': False, 'message': 'Missing required booking fields.'}), 400
    
    cnx = get_db_connection()
    if cnx is None: return jsonify({'success': False, 'message': 'Database connection failed'}), 500

    try:
        cursor = cnx.cursor()
        # Call the Stored Procedure for Atomic Booking (sp_book_reservation)
        cursor.callproc('sp_book_reservation', (current_user_id, event_id, no_of_tickets, ticket_category, payment_method, 0, ''))
        cnx.commit()
        return jsonify({'success': True, 'message': 'Reservation successful! Check My Reservations.'})
    except mysql.connector.Error as err:
        error_message = f"Booking failed. Error code: {err.errno} - {err.msg}"
        logging.error(f"Booking SP failure: {error_message}")
        return jsonify({'success': False, 'message': error_message}), 400
    finally:
        if cnx.is_connected(): cursor.close(); cnx.close()

@app.route('/cancel_reservation/<int:reservation_id>', methods=['POST'])
def cancel_reservation(reservation_id):
    # Fix: Get JSON body (which contains the required reason)
    data = request.get_json()
    if not data or 'cancellation_reason' not in data:
         return jsonify({'success': False, 'message': 'Cancellation failed: Missing reason.'}), 400
         
    cancellation_reason = data['cancellation_reason']
    
    cnx = get_db_connection()
    if cnx is None: return jsonify({'success': False, 'message': 'Database connection failed'}), 500
    try:
        cursor = cnx.cursor()
        # Call existing Stored Procedure for cancellation (sp_cancel_reservation)
        # Fix for 'expected 2, got 1' error: we now pass the reason
        cursor.callproc('sp_cancel_reservation', (reservation_id, cancellation_reason))
        cnx.commit()
        return jsonify({'success': True, 'message': f'Reservation {reservation_id} successfully cancelled.'})
    except mysql.connector.Error as err:
        logging.error(f"Cancellation failed: {err}")
        return jsonify({'success': False, 'message': f'Cancellation failed. Error: {err.msg}'}), 400
    finally:
        if cnx.is_connected(): cursor.close(); cnx.close()

@app.route('/process_refund/<int:reservation_id>', methods=['POST'])
def process_refund(reservation_id):
    
    # We need to fetch payment and amount details first.
    
    conn = get_db_connection()
    if conn is None:
        return jsonify({'success': False, 'message': 'Database connection failed.'}), 500
        
    try:
        cursor = conn.cursor(dictionary=True)
        # Query to get the payment details associated with the reservation
        cursor.execute("""
            SELECT 
                p.payment_id, p.payment_amount 
            FROM payments p 
            WHERE p.reservation_id = %s AND p.payment_status = 'Successful'
        """, (reservation_id,))
        
        payment_data = cursor.fetchone()
        
        if not payment_data:
            return jsonify({'success': False, 'message': 'Refund failed: No successful payment found for this reservation.'}), 400

        payment_id = payment_data['payment_id']
        refund_amount = payment_data['payment_amount']
        
        # Call the Stored Procedure for refund processing (sp_process_refund)
        # The SP is expected to take 3 IN args: reservation_id, refund_amount, payment_id
        # And 2 OUT args: p_success, p_message (Total 5)
        cursor.callproc('sp_process_refund', (reservation_id, refund_amount, payment_id, 0, ''))
        conn.commit()
        
        return jsonify({'success': True, 'message': f'Refund request for reservation {reservation_id} processed for ₹{refund_amount}.'}), 200

    except mysql.connector.Error as err:
        logging.error(f"Refund failed: {err}")
        return jsonify({'success': False, 'message': f'Refund failed. Error: {err.msg}'}), 400
    finally:
        if conn.is_connected(): cursor.close(); conn.close()

if __name__ == '__main__':
    app.run(debug=True)
