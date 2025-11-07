# Smart Multi Event Booking System with Analytics

## 🎯 Project Overview

This project implements a full-stack, data-driven application designed for managing event ticketing and reservations. The primary focus is on demonstrating proficiency in robust database design, concurrency control, and complex analytical reporting using stored programs.

**Developed By:** [Your Name(s) and Student ID(s)]

## ✨ Key Features & Technical Complexity

The application is built around the following complex database objects to ensure high marks for system design:

* **Atomic Transactions:** Uses the `sp_book_reservation` Stored Procedure to ensure capacity is checked and the multi-table reservation (Reservations, Payments, Tickets) is committed atomically.
* **Analytics Dashboard:** Generates real-time Key Performance Indicators (KPIs) and reports using database Functions (`calculate_total_revenue`, `fn_avg_ticket_price`) and complex Stored Procedures (`sp_popular_events`, `sp_most_popular_venue`).
* **Auditing:** Employs Triggers (`trg_reservation_modification_log`) to automatically maintain an audit trail for critical updates and status changes.
* **GUI:** Fully functional Admin CRUD interface with form validation and user-side transactional controls (Cancel, Refund).

## 🛠️ Technology Stack

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Database** | **MySQL** | Core Relational Data Management System. |
| **Backend** | **Python (Flask)** | Server-side logic, API routing, and database communication. |
| **Connectivity** | `mysql-connector-python` | Driver used by Python to execute SQL commands. |
| **Frontend** | **HTML5, Jinja2, JavaScript** | Structure and dynamic content rendering. |
| **Styling** | **Tailwind CSS** | Responsive and modern application layout. |

## 🚀 Setup and Execution Guide

Follow these steps to set up and run the application.

### Step 1: Database Setup (MySQL)

1.  **Create Database:** Log into your MySQL client and create the schema:
    ```sql
    CREATE DATABASE event_booking_system;
    USE event_booking_system;
    ```
2.  **Define Structure and Logic:** Execute all the SQL files located in the **`SQL_DEFINITIONS/`** folder. Run them in the following order:
    * `01_schema_setup.sql` (Creates all tables and inserts sample data)
    * `02_triggers.sql` (Creates Triggers)
    * `03_functions.sql` (Creates all Functions and the View)
    * `04_procedures.sql` (Creates all Stored Procedures)
3.  **Update Credentials:** Open `app.py` and update the `DB_CONFIG` dictionary (lines 20-24) with your correct MySQL username and password.

### Step 2: Python Environment

1.  **Install Dependencies:** Navigate to the root folder of the project in your terminal and install the required packages:
    ```bash
    pip install -r requirements.txt
    ```

### Step 3: Run the Application

1.  Execute the Flask application from the root directory:
    ```bash
    python app.py
    ```
2.  Open your browser and navigate to the application address:
    **`http://127.0.0.1:5000/`**

### Step 4: Testing Key Functionality

* **Admin Test:** Use the **Admin Panel** to create a new event.
* **Transaction Test:** Use the **Booking Tab** to make a reservation and verify the change in the **My Reservations** tab.
* **Analytics Proof:** Navigate to the **Analytics Tab** to confirm that all KPIs (Revenue, Avg Price) and reports are populated, proving the SQL functions and procedures are executing correctly.