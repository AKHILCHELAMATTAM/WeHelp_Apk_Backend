# Field Agent & Donation Management System - Backend REST APIs

A production-grade Python Django REST Framework (DRF) backend implementing the end-to-end mobile app workflow for Field Agents and Administrators.

---

## 📋 Workflow Implementation Matrix

This backend provides a 1-to-1 mapping with each node in the system workflow diagram:

| Workflow Diagram Node | Actor | HTTP Method & Endpoint | Description |
| :--- | :--- | :--- | :--- |
| **Open Android App -> Select User Role** | Both | `POST /api/auth/login/` | Select `ADMIN` or `AGENT` role & validate credentials |
| **Credentials Valid? (Yes / No)** | Both | `POST /api/auth/login/` | Returns JWT tokens on success or clear error on failure |
| **Agent Creation -> Create Agent Username/Password -> Save Agent Account** | Admin | `POST /api/admin/agents/` | Admin creates new field agent with assigned territory |
| **Access Location -> Request GPS Permission -> Capture -> Send Location** | Agent | `POST /api/agent/location/` | Reports real-time GPS coordinates, battery, and address |
| **Agent Location Tracking -> View Location on Map / Lat-Long** | Admin | `GET /api/admin/tracking/live/`<br>`GET /api/admin/tracking/agents/<id>/history/` | Live map markers and breadcrumb route history |
| **Donation Entry -> Cash -> Enter Cash -> Save Record -> Update Details** | Agent | `POST /api/agent/donations/cash/`<br>`PATCH /api/agent/donations/<id>/` | Records cash donation, issues receipt, updates details |
| **Donation Entry -> Products -> Enter Product/Grocery -> Save Record** | Agent | `POST /api/agent/donations/product/`<br>`PATCH /api/agent/donations/<id>/` | Records grocery/product donations in kg, boxes, etc. |
| **Payment Details -> View or Manage Payment Records** | Admin | `GET /api/admin/payments/records/`<br>`PATCH /api/admin/payments/records/<id>/` | Manage cash settlements, payment modes, and statuses |
| **Attendance -> Display Today's Target -> View Daily Target** | Agent | `POST /api/agent/attendance/check-in/`<br>`GET /api/agent/target/today/` | Check-in/out and live target vs. achieved progress |
| **Leave or Week-Off Request -> Submit Request to Admin** | Agent | `POST /api/agent/leaves/`<br>`GET /api/agent/leaves/` | Submit leave/week-off requests and track status |
| **Leave Management -> View Requests -> Approve / Reject** | Admin | `GET /api/admin/leaves/`<br>`POST /api/admin/leaves/<id>/review/` | Review and Approve or Reject agent leave requests |
| **Admin Dashboard & Agent Dashboard** | Both | `GET /api/admin/dashboard/`<br>`GET /api/agent/dashboard/` | Consolidated summary cards, KPIs, and recent activity |

---

## 🚀 Quickstart Guide

### 1. Requirements & Dependencies
Ensure Python 3.10+ is installed. Install required packages:
```bash
pip install -r requirements.txt
```

### 2. Database Migrations
Apply database migrations:
```bash
python manage.py migrate
```

### 3. Seed Realistic Sample Data
Populate the database with pre-configured Admin, field agents, daily targets, attendance, donations, GPS coordinates, and leave requests:
```bash
python manage.py seed_data
```

### 4. Run Development Server
```bash
python manage.py runserver 0.0.0.0:8000
```
Open **[http://127.0.0.1:8000/](http://127.0.0.1:8000/)** in your browser to view the interactive API root catalog.

---

## 🔑 Default Credentials (from `seed_data`)

| Role | Username | Password | Notes |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin` | `Admin@1234` | Full access to Admin Dashboard, Agent Creation, Location Tracking, Payments, Leaves |
| **Agent 1** | `agent_rahul` | `Agent@1234` | Field Agent (North Zone Delhi NCR, Target: ₹10,000) |
| **Agent 2** | `agent_priya` | `Agent@1234` | Field Agent (South Zone Bengaluru, Target: ₹8,000) |

---

## 📬 Postman Collections & Environments

Ready-to-import Postman files are provided for both **Render Cloud Deployment** and **Local Development**:

### ☁️ Render Production Deployment
- **Collection:** **`wehelp_render_api.postman_collection.json`** (`baseUrl`: `https://wehelp-apk-backend.onrender.com`)
- **Environment:** **`wehelp_render_environment.postman_environment.json`**

### 💻 Local Development
- **Collection:** **`field_agent_api.postman_collection.json`** (`baseUrl`: `http://127.0.0.1:8000`)
- **Environment:** **`field_agent_environment.postman_environment.json`**

### How to Import and Use:
1. Open Postman, click **Import**, and drag & drop `wehelp_render_api.postman_collection.json` and `wehelp_render_environment.postman_environment.json`.
2. Select **WeHelp APK Backend - Render Environment** from the top-right environment selector.
3. Open folder `1. Authentication & Profile` -> run **Admin Login**: Postman's test script automatically captures the live JWT token and saves it to `{{admin_token}}`.
4. Run **Agent Login**: The test script automatically saves the token to `{{agent_token}}`.
5. You can now execute any Admin or Agent workflow request seamlessly against your Render backend!

---

## 📖 API Documentation & Swagger UI

Interactive OpenAPI 3.0 documentation is available directly in the browser:

- **Swagger UI:** [http://127.0.0.1:8000/api/docs/](http://127.0.0.1:8000/api/docs/)
- **ReDoc:** [http://127.0.0.1:8000/api/redoc/](http://127.0.0.1:8000/api/redoc/)
- **Raw OpenAPI Schema:** [http://127.0.0.1:8000/api/schema/](http://127.0.0.1:8000/api/schema/) (or file: `openapi-schema.yaml`)

---

## 🔌 API Endpoints Reference

### 1. Authentication (`accounts`)
- `POST /api/auth/login/` - Role-based login (requires `username`, `password`, `role`: `ADMIN` or `AGENT`).
- `POST /api/auth/token/refresh/` - Refresh expired access token.
- `GET /api/auth/profile/` - View current user profile.
- `PATCH /api/auth/profile/` - Update user profile.

### 2. Admin Management (`accounts`)
- `GET /api/admin/dashboard/` - Admin overview KPIs, online agents, pending leaves, today's collections.
- `GET /api/admin/agents/` - List all field agents with filtering (`search`, `is_active`).
- `POST /api/admin/agents/` - Create new agent account (`username`, `password`, `employee_id`, `assigned_area`).
- `GET /api/admin/agents/<id>/` - Retrieve agent details.
- `PATCH /api/admin/agents/<id>/` - Update agent details.
- `POST /api/admin/agents/<id>/toggle-status/` - Activate or deactivate agent account.

### 3. GPS Location Tracking (`tracking`)
- `POST /api/agent/location/` - Agent reports GPS fix (`latitude`, `longitude`, `accuracy`, `speed`, `battery_level`, `address`).
- `GET /api/agent/location/latest/` - Agent's last recorded location.
- `GET /api/admin/tracking/live/` - Real-time map coordinates for all active field agents with online/offline status.
- `GET /api/admin/tracking/agents/<agent_id>/history/?date=YYYY-MM-DD` - Chronological route history for a specific agent.

### 4. Donations & Payments (`donations`)
- `POST /api/agent/donations/cash/` - Enter cash donation (`amount`, `payment_mode`: CASH/UPI/CARD, `donor_name`, `donor_phone`). Auto-generates receipt.
- `POST /api/agent/donations/product/` - Enter product/grocery donation (`product_name`, `product_category`, `quantity`, `unit`, `donor_name`).
- `GET /api/agent/donations/` - List donations recorded by the agent (filter by `donation_type`, `date`).
- `GET /api/agent/donations/<id>/` - View specific donation & receipt details.
- `PATCH /api/agent/donations/<id>/` - Update donation details (donor info, notes, product quantity).
- `GET /api/agent/donations/summary/` - Agent's daily collection summary.
- `GET /api/admin/donations/` - List all donations (filter by `agent_id`, `donation_type`, `date`, `search`).
- `POST /api/admin/donations/<id>/verify/` - Verify donation record.
- `GET /api/admin/payments/records/` - View all financial payment transactions.
- `PATCH /api/admin/payments/records/<id>/` - Update payment settlement status (`COMPLETED`, `PENDING`, `REFUNDED`).
- `GET /api/admin/payments/summary/` - Financial breakdown by payment mode, today's total, and overall collection.

### 5. Attendance & Daily Targets (`attendance`)
- `POST /api/agent/attendance/check-in/` - Record daily check-in with GPS coordinates & address.
- `POST /api/agent/attendance/check-out/` - Record daily check-out with GPS coordinates.
- `GET /api/agent/attendance/status/` - Current check-in/out status for today.
- `GET /api/agent/attendance/history/` - Historical attendance records.
- `GET /api/agent/target/today/` - View today's target alongside real-time achieved amount, count, units, and completion %.
- `GET /api/admin/attendance/` - View attendance records across all field agents.
- `POST /api/admin/targets/` - Assign daily targets (`target_cash_amount`, `target_donations_count`, `target_product_units`) to an agent.

### 6. Leaves & Week-Offs (`leaves`)
- `POST /api/agent/leaves/` - Submit leave/week-off request (`request_type`: `LEAVE` or `WEEK_OFF`, `start_date`, `end_date`, `reason`).
- `GET /api/agent/leaves/` - View submitted requests and their approval/rejection status.
- `GET /api/admin/leaves/` - Admin list of all leave requests (filter by `status`, `request_type`, `agent_id`).
- `POST /api/admin/leaves/<id>/review/` - Admin approves (`APPROVE`) or rejects (`REJECT`) with optional remarks.

---

## 🧪 Automated Test Suite

A complete test suite covering all 18 workflow scenarios:
```bash
python manage.py test
```
Result: **18 tests passing (100% success rate)**.
