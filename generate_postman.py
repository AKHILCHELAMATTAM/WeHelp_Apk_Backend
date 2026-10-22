import json
import os

collection = {
    "info": {
        "_postman_id": "wehelp-backend-api-v2",
        "name": "WeHelp Field Operations & Donation Management Backend API",
        "description": "Comprehensive Postman Collection covering all endpoints for WeHelp Agent Mobile App and Admin Web Management.\n\nIncludes:\n- Role-based Authentication (Admin/Agent) with auto-token extraction\n- Dashboards & Real-time Metrics\n- Live GPS Location Tracking & Google Maps Integration\n- Attendance Check-In / Check-Out with GPS Coordinates & Reverse-Geocoded Address\n- Daily Target Assignment & Progress Tracking\n- Cash & Product/Grocery In-Kind Donations with Receipt Generation\n- Organization Bank Details (Account 3113201002320) for UPI/QR\n- Admin Financial Payment Records & Settlement\n- Leave & Weekly-Off Request & Approval Workflow\n- Field Agent Account Management",
        "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
    },
    "variable": [
        {"key": "baseUrl", "value": "http://3.110.92.188", "type": "string"},
        {"key": "admin_username", "value": "admin", "type": "string"},
        {"key": "admin_password", "value": "admin123", "type": "string"},
        {"key": "agent_username", "value": "agent_rahul", "type": "string"},
        {"key": "agent_password", "value": "agent123", "type": "string"},
        {"key": "admin_token", "value": "", "type": "string"},
        {"key": "agent_token", "value": "", "type": "string"},
        {"key": "admin_refresh_token", "value": "", "type": "string"},
        {"key": "agent_refresh_token", "value": "", "type": "string"},
        {"key": "agent_id", "value": "1", "type": "string"},
        {"key": "donation_id", "value": "1", "type": "string"},
        {"key": "leave_id", "value": "1", "type": "string"},
        {"key": "target_id", "value": "1", "type": "string"}
    ],
    "item": []
}

def make_req(name, method, url_path, auth_type=None, body=None, params=None, desc="", test_script=""):
    url_obj = {
        "raw": "{{baseUrl}}" + url_path,
        "host": ["{{baseUrl}}"],
        "path": [p for p in url_path.strip("/").split("/") if p]
    }
    if params:
        url_obj["query"] = [{"key": k, "value": v, "description": d} for k, v, d in params]

    req = {
        "name": name,
        "request": {
            "method": method,
            "header": [
                {"key": "Accept", "value": "application/json", "type": "text"}
            ],
            "url": url_obj,
            "description": desc
        },
        "response": []
    }

    if auth_type == "admin":
        req["request"]["header"].append({
            "key": "Authorization",
            "value": "Bearer {{admin_token}}",
            "type": "text"
        })
    elif auth_type == "agent":
        req["request"]["header"].append({
            "key": "Authorization",
            "value": "Bearer {{agent_token}}",
            "type": "text"
        })

    if body is not None:
        req["request"]["header"].append({
            "key": "Content-Type",
            "value": "application/json",
            "type": "text"
        })
        req["request"]["body"] = {
            "mode": "raw",
            "raw": json.dumps(body, indent=2)
        }

    if test_script:
        req["event"] = [
            {
                "listen": "test",
                "script": {
                    "type": "text/javascript",
                    "exec": test_script.strip().split("\n")
                }
            }
        ]

    return req

# ==========================================
# 1. AUTHENTICATION & SETUP
# ==========================================
auth_login_admin_test = """
if (pm.response.code === 200) {
    var data = pm.response.json();
    if (data.tokens && data.tokens.access) {
        pm.collectionVariables.set("admin_token", data.tokens.access);
        pm.collectionVariables.set("admin_refresh_token", data.tokens.refresh);
        console.log("Admin JWT Access Token saved to {{admin_token}}");
    }
}
"""

auth_login_agent_test = """
if (pm.response.code === 200) {
    var data = pm.response.json();
    if (data.tokens && data.tokens.access) {
        pm.collectionVariables.set("agent_token", data.tokens.access);
        pm.collectionVariables.set("agent_refresh_token", data.tokens.refresh);
        if (data.user && data.user.id) {
            pm.collectionVariables.set("agent_id", data.user.id);
        }
        console.log("Agent JWT Access Token saved to {{agent_token}}");
    }
}
"""

folder_auth = {
    "name": "1. Authentication & System Setup",
    "description": "Role-based login for Admins & Agents, JWT token refreshing, user profiles, and cloud database setup.",
    "item": [
        make_req(
            "Admin Login",
            "POST",
            "/api/auth/login/",
            body={"username": "{{admin_username}}", "password": "{{admin_password}}", "role": "ADMIN"},
            desc="Authenticates with ADMIN role. Automatically extracts JWT access token and saves into collection variable {{admin_token}}.",
            test_script=auth_login_admin_test
        ),
        make_req(
            "Agent Login",
            "POST",
            "/api/auth/login/",
            body={"username": "{{agent_username}}", "password": "{{agent_password}}", "role": "AGENT"},
            desc="Authenticates with AGENT role. Automatically extracts JWT access token and saves into collection variable {{agent_token}}.",
            test_script=auth_login_agent_test
        ),
        make_req(
            "Refresh JWT Token",
            "POST",
            "/api/auth/token/refresh/",
            body={"refresh": "{{admin_refresh_token}}"},
            desc="Refreshes expired access token using the stored refresh token."
        ),
        make_req(
            "Get Current User Profile",
            "GET",
            "/api/auth/profile/",
            auth_type="agent",
            desc="Fetches profile details, employee ID, assigned area, and active status for currently logged-in user."
        ),
        make_req(
            "Update User Profile",
            "PUT",
            "/api/auth/profile/",
            auth_type="agent",
            body={
                "first_name": "Rahul",
                "last_name": "Sharma",
                "email": "rahul.agent@wehelp.org",
                "phone_number": "+919876543210",
                "assigned_area": "North Zone - Indiranagar"
            },
            desc="Updates contact details for the authenticated user."
        ),
        make_req(
            "Database Initial Cloud Setup & Seed",
            "POST",
            "/api/auth/setup-seed/",
            body={"secret_key": "wehelp-initial-seed-2026"},
            desc="Initializes database migrations and seeds initial admin and agent users on fresh cloud deployments."
        )
    ]
}

# ==========================================
# 2. DASHBOARDS
# ==========================================
folder_dashboards = {
    "name": "2. Dashboards",
    "description": "High-level summary endpoints for Admin web dashboard and Agent mobile home screen.",
    "item": [
        make_req(
            "Admin Dashboard Overview",
            "GET",
            "/api/admin/dashboard/",
            auth_type="admin",
            desc="Provides complete organization metrics: total collections, today's collections, active agents count, online agents, pending leave requests, pending verification records."
        ),
        make_req(
            "Agent Dashboard Overview",
            "GET",
            "/api/agent/dashboard/",
            auth_type="agent",
            desc="Provides agent's daily summary: today's collection amount, daily target progress, today's attendance check-in status, and recent donation receipts."
        )
    ]
}

# ==========================================
# 3. LIVE GPS LOCATION & TRACKING
# ==========================================
folder_tracking = {
    "name": "3. Live GPS Location & Tracking",
    "description": "Agent live GPS ping submission, reverse geocoding, admin live map tracking, and agent location breadcrumbs.",
    "item": [
        make_req(
            "Agent Send Live Location Ping",
            "POST",
            "/api/agent/location/",
            auth_type="agent",
            body={
                "latitude": 12.9716,
                "longitude": 77.5946,
                "accuracy": 4.5,
                "speed": 1.2,
                "altitude": 920.0,
                "battery_level": 85,
                "address": "MG Road, Indiranagar, Bengaluru, Karnataka - 560038",
                "recorded_at": "2026-10-19T10:00:00Z"
            },
            desc="Mobile app calls this endpoint to transmit the agent's live GPS coordinates, battery level, and resolved street address to the server."
        ),
        make_req(
            "Agent Get Own Latest Location",
            "GET",
            "/api/agent/location/latest/",
            auth_type="agent",
            desc="Retrieves the most recent location recorded for the authenticated agent."
        ),
        make_req(
            "Admin Track All Field Agents Live",
            "GET",
            "/api/admin/tracking/live/",
            auth_type="admin",
            desc="Returns latest GPS coordinates, battery, physical address, online/offline status, and direct Google Maps link for every active field agent."
        ),
        make_req(
            "Admin View Agent Location History",
            "GET",
            "/api/admin/tracking/agents/{{agent_id}}/history/",
            auth_type="admin",
            params=[("date", "2026-10-19", "Filter history by date (YYYY-MM-DD)")],
            desc="Returns time-ordered GPS breadcrumb path for a specific agent on a given date."
        )
    ]
}

# ==========================================
# 4. ATTENDANCE & CHECK-IN
# ==========================================
folder_attendance = {
    "name": "4. Attendance & Check-In",
    "description": "Daily attendance check-in / check-out with GPS coordinates, reverse-geocoded physical address, and history logs.",
    "item": [
        make_req(
            "Agent Mark Check-In (with GPS)",
            "POST",
            "/api/agent/attendance/check-in/",
            auth_type="agent",
            body={
                "latitude": 12.9716,
                "longitude": 77.5946,
                "accuracy": 3.8,
                "address": "42, 5th Cross, Indiranagar, Bengaluru, Karnataka - 560038",
                "notes": "Morning field shift check-in"
            },
            desc="Records agent's check-in timestamp, coordinates, and exact address. Generates Google Maps pin and updates live tracking."
        ),
        make_req(
            "Agent Mark Check-Out (with GPS)",
            "POST",
            "/api/agent/attendance/check-out/",
            auth_type="agent",
            body={
                "latitude": 12.9720,
                "longitude": 77.5950,
                "accuracy": 4.1,
                "address": "42, 5th Cross, Indiranagar, Bengaluru, Karnataka - 560038",
                "notes": "Evening shift completed"
            },
            desc="Records agent's check-out timestamp, coordinates, and calculates total shift working hours."
        ),
        make_req(
            "Agent Get Today Attendance Status",
            "GET",
            "/api/agent/attendance/status/",
            auth_type="agent",
            desc="Checks whether agent has checked in, checked out, and returns Google Maps links and working duration for today."
        ),
        make_req(
            "Agent Attendance History",
            "GET",
            "/api/agent/attendance/history/",
            auth_type="agent",
            desc="Returns list of past attendance records for the authenticated agent."
        ),
        make_req(
            "Admin List All Attendance Records",
            "GET",
            "/api/admin/attendance/",
            auth_type="admin",
            params=[
                ("date", "2026-10-19", "Filter by specific date YYYY-MM-DD"),
                ("agent_id", "{{agent_id}}", "Filter by agent ID"),
                ("status", "PRESENT", "PRESENT, ABSENT, HALF_DAY, ON_LEAVE")
            ],
            desc="Admin list of attendance logs with check-in/out times, physical addresses, and Google Maps links."
        )
    ]
}

# ==========================================
# 5. DAILY TARGETS
# ==========================================
folder_targets = {
    "name": "5. Daily Targets",
    "description": "Admin daily target assignments and Agent real-time target goal vs. achieved progress tracking.",
    "item": [
        make_req(
            "Agent View Today Target & Progress",
            "GET",
            "/api/agent/target/today/",
            auth_type="agent",
            desc="Returns assigned cash target, donation count target, product units target, along with real-time achieved metrics and percentages."
        ),
        make_req(
            "Admin List Target Assignments",
            "GET",
            "/api/admin/targets/",
            auth_type="admin",
            params=[("date", "2026-10-19", "Filter targets by date")],
            desc="Lists all agent target goals assigned across dates."
        ),
        make_req(
            "Admin Assign Daily Target to Agent",
            "POST",
            "/api/admin/targets/",
            auth_type="admin",
            body={
                "agent": 1,
                "date": "2026-10-20",
                "target_cash_amount": "5000.00",
                "target_donations_count": 10,
                "target_product_units": 5,
                "notes": "Festival donation drive in Market Ward"
            },
            desc="Admin assigns target numbers to an agent for a specific day."
        ),
        make_req(
            "Admin Retrieve Target Details",
            "GET",
            "/api/admin/targets/{{target_id}}/",
            auth_type="admin",
            desc="Retrieves specific target assignment details."
        ),
        make_req(
            "Admin Update Target Assignment",
            "PUT",
            "/api/admin/targets/{{target_id}}/",
            auth_type="admin",
            body={
                "agent": 1,
                "date": "2026-10-20",
                "target_cash_amount": "6000.00",
                "target_donations_count": 12,
                "target_product_units": 8,
                "notes": "Revised target for festival donation drive"
            },
            desc="Admin updates target figures."
        ),
        make_req(
            "Admin Delete Target Assignment",
            "DELETE",
            "/api/admin/targets/{{target_id}}/",
            auth_type="admin",
            desc="Deletes a target assignment record."
        )
    ]
}

# ==========================================
# 6. DONATIONS & COLLECTIONS
# ==========================================
folder_donations = {
    "name": "6. Donations & Collections",
    "description": "Cash/UPI and In-Kind Product/Grocery donations, receipts generation, Bank Details configuration, and verification.",
    "item": [
        make_req(
            "Agent Get Organization Bank Details (for UPI/QR)",
            "GET",
            "/api/agent/bank-details/",
            auth_type="agent",
            desc="Returns active organization bank account details (Account: 3113201002320, IFSC: CNRB0003113, Canara Bank, UPI VPA: 3113201002320@cnrb) for donation collection."
        ),
        make_req(
            "Admin View Organization Bank Details",
            "GET",
            "/api/admin/bank-details/",
            auth_type="admin",
            desc="Admin view of current active organization bank details."
        ),
        make_req(
            "Admin Update Organization Bank Details",
            "PUT",
            "/api/admin/bank-details/",
            auth_type="admin",
            body={
                "account_holder_name": "WE HELP CHARITABLE SOCIETY AND EDUCATION",
                "bank_name": "Canara Bank",
                "account_number": "3113201002320",
                "ifsc_code": "CNRB0003113",
                "account_type": "Current Account",
                "upi_id": "3113201002320@cnrb",
                "branch_name": "Main Branch",
                "is_active": True
            },
            desc="Admin updates the official organization bank account displayed in the agent mobile APK."
        ),
        make_req(
            "Agent Record Cash / UPI Monetary Donation",
            "POST",
            "/api/agent/donations/cash/",
            auth_type="agent",
            body={
                "donor_name": "Vikram Singh",
                "donor_phone": "+919876543210",
                "donor_email": "vikram.singh@gmail.com",
                "donor_address": "Flat 302, Green Meadows, Bengaluru",
                "amount": "1500.00",
                "currency": "INR",
                "payment_mode": "UPI",
                "transaction_reference": "UPI/20261019/987123654",
                "notes": "Field donation via UPI QR code",
                "latitude": 12.9716,
                "longitude": 77.5946
            },
            desc="Records a monetary donation, creates receipt number (DON-YYYYMMDD-XXXXXX), and logs GPS coordinates."
        ),
        make_req(
            "Agent Record Product / Grocery In-Kind Donation",
            "POST",
            "/api/agent/donations/product/",
            auth_type="agent",
            body={
                "donor_name": "Anita Sharma",
                "donor_phone": "+919812345678",
                "donor_email": "anita.s@outlook.com",
                "donor_address": "12, 1st Cross, HAL 2nd Stage, Bengaluru",
                "product_name": "Basmati Rice",
                "product_category": "Grocery",
                "quantity": "25.00",
                "unit": "kg",
                "estimated_value": "2000.00",
                "notes": "Rice bag donation for community kitchen",
                "latitude": 12.9716,
                "longitude": 77.5946
            },
            desc="Records in-kind grocery or supply items (rice, wheat, blankets, medicines) with quantity and unit."
        ),
        make_req(
            "Agent List Own Donations",
            "GET",
            "/api/agent/donations/",
            auth_type="agent",
            params=[
                ("donation_type", "CASH", "CASH or PRODUCT"),
                ("date", "2026-10-19", "Filter by date YYYY-MM-DD")
            ],
            desc="Lists donations collected by the authenticated agent."
        ),
        make_req(
            "Agent Retrieve Donation Detail",
            "GET",
            "/api/agent/donations/{{donation_id}}/",
            auth_type="agent",
            desc="Retrieves full details of a specific donation record."
        ),
        make_req(
            "Agent Update Donation Details",
            "PUT",
            "/api/agent/donations/{{donation_id}}/",
            auth_type="agent",
            body={
                "donor_name": "Vikram Singh",
                "donor_phone": "+919876543210",
                "donor_email": "vikram.singh@gmail.com",
                "donor_address": "Flat 302, Green Meadows, Bengaluru",
                "amount": "1500.00",
                "payment_mode": "UPI",
                "transaction_reference": "UPI/20261019/987123654-UPDATED",
                "notes": "Added corrected transaction reference"
            },
            desc="Updates notes, contact details, or transaction reference of a donation."
        ),
        make_req(
            "Agent Donations Summary (Today & All-Time)",
            "GET",
            "/api/agent/donations/summary/",
            auth_type="agent",
            desc="Returns summary statistics: total cash amount, count of cash and product donations collected today."
        ),
        make_req(
            "Admin List All Donations",
            "GET",
            "/api/admin/donations/",
            auth_type="admin",
            params=[
                ("donation_type", "CASH", "CASH or PRODUCT"),
                ("agent_id", "{{agent_id}}", "Filter by agent ID"),
                ("date", "2026-10-19", "Filter by date"),
                ("search", "Vikram", "Search donor name, phone, receipt or product")
            ],
            desc="Admin list of all donations across all agents with search and filter capabilities."
        ),
        make_req(
            "Admin View Donation Detail",
            "GET",
            "/api/admin/donations/{{donation_id}}/",
            auth_type="admin",
            desc="Admin retrieve single donation record."
        ),
        make_req(
            "Admin Edit Donation Record",
            "PUT",
            "/api/admin/donations/{{donation_id}}/",
            auth_type="admin",
            body={
                "donor_name": "Vikram Singh",
                "donor_phone": "+919876543210",
                "amount": "1500.00",
                "notes": "Verified by admin"
            },
            desc="Admin can edit any donation record."
        ),
        make_req(
            "Admin Delete Donation Record",
            "DELETE",
            "/api/admin/donations/{{donation_id}}/",
            auth_type="admin",
            desc="Admin deletes a donation record."
        ),
        make_req(
            "Admin Verify Donation Record",
            "POST",
            "/api/admin/donations/{{donation_id}}/verify/",
            auth_type="admin",
            desc="Marks a donation record status as VERIFIED and attaches admin verification audit trail."
        )
    ]
}

# ==========================================
# 7. PAYMENT RECORDS (FINANCIAL MANAGEMENT)
# ==========================================
folder_payments = {
    "name": "7. Payment Records (Admin Financial)",
    "description": "Financial payment transaction records, settlement status, and revenue breakdown by payment modes (Cash, UPI, Card, Bank Transfer).",
    "item": [
        make_req(
            "Admin List Payment Records",
            "GET",
            "/api/admin/payments/records/",
            auth_type="admin",
            params=[
                ("payment_mode", "UPI", "CASH, UPI, CARD, BANK_TRANSFER, CHEQUE"),
                ("payment_status", "COMPLETED", "COMPLETED, PENDING, FAILED, REFUNDED"),
                ("agent_id", "{{agent_id}}", "Filter by agent"),
                ("date", "2026-10-19", "Filter by date")
            ],
            desc="Lists financial transactions with payment mode, donor, agent, settlement status, and reference numbers."
        ),
        make_req(
            "Admin View Payment Record Detail",
            "GET",
            "/api/admin/payments/records/{{donation_id}}/",
            auth_type="admin",
            desc="Retrieves payment transaction record details."
        ),
        make_req(
            "Admin Update Payment Settlement Status",
            "PATCH",
            "/api/admin/payments/records/{{donation_id}}/",
            auth_type="admin",
            body={
                "payment_status": "COMPLETED",
                "transaction_reference": "BANK-SETTLE-88991122",
                "notes": "Bank statement reconciled and cleared"
            },
            desc="Updates settlement status (COMPLETED, PENDING, FAILED, REFUNDED) and reconciliation remarks."
        ),
        make_req(
            "Admin Financial & Payment Summary",
            "GET",
            "/api/admin/payments/summary/",
            auth_type="admin",
            desc="Returns overall financial overview: today's collection, all-time revenue, breakdown by payment modes (UPI, Cash, etc.), and status breakdown."
        )
    ]
}

# ==========================================
# 8. LEAVES & WEEKLY-OFF MANAGEMENT
# ==========================================
folder_leaves = {
    "name": "8. Leaves & Weekly-Off Management",
    "description": "Leave and weekly-off request submissions by agents and admin review/approval/rejection workflow.",
    "item": [
        make_req(
            "Agent Submit Leave or Weekly-Off Request",
            "POST",
            "/api/agent/leaves/",
            auth_type="agent",
            body={
                "request_type": "LEAVE",
                "start_date": "2026-10-25",
                "end_date": "2026-10-26",
                "reason": "Family function and travel to hometown"
            },
            desc="Agent submits a leave or week-off request (request_type: LEAVE or WEEK_OFF). Total days are automatically calculated."
        ),
        make_req(
            "Agent List Own Leave Requests",
            "GET",
            "/api/agent/leaves/",
            auth_type="agent",
            desc="Returns agent's past and pending leave requests with approval status, reviewer name, and admin remarks."
        ),
        make_req(
            "Agent View Leave Request Detail",
            "GET",
            "/api/agent/leaves/{{leave_id}}/",
            auth_type="agent",
            desc="Retrieves single leave request details."
        ),
        make_req(
            "Admin List All Leave Requests",
            "GET",
            "/api/admin/leaves/",
            auth_type="admin",
            params=[
                ("status", "PENDING", "PENDING, APPROVED, REJECTED"),
                ("request_type", "LEAVE", "LEAVE or WEEK_OFF"),
                ("agent_id", "{{agent_id}}", "Filter by agent ID")
            ],
            desc="Admin list of leave requests from all field agents."
        ),
        make_req(
            "Admin View Leave Request Detail",
            "GET",
            "/api/admin/leaves/{{leave_id}}/",
            auth_type="admin",
            desc="Admin view of specific leave request."
        ),
        make_req(
            "Admin Approve or Reject Leave Request",
            "POST",
            "/api/admin/leaves/{{leave_id}}/review/",
            auth_type="admin",
            body={
                "action": "APPROVE",
                "admin_remarks": "Approved by Duty Roster Manager"
            },
            desc="Admin reviews request with decision (APPROVE or REJECT) and optional remarks. Updates status badge in mobile app."
        )
    ]
}

# ==========================================
# 9. AGENT USER MANAGEMENT (ADMIN)
# ==========================================
folder_agents = {
    "name": "9. Agent User Management (Admin)",
    "description": "Admin endpoints to create field agent accounts, assign passwords, update assigned areas, and toggle active status.",
    "item": [
        make_req(
            "Admin List All Field Agents",
            "GET",
            "/api/admin/agents/",
            auth_type="admin",
            params=[
                ("is_active_agent", "true", "true or false"),
                ("search", "rahul", "Search username, name, phone, employee ID, or area")
            ],
            desc="Lists all field agents with contact details, assigned areas, employee IDs, and activity status."
        ),
        make_req(
            "Admin Create New Field Agent Account",
            "POST",
            "/api/admin/agents/",
            auth_type="admin",
            body={
                "username": "agent_suresh",
                "password": "agentPassword123!",
                "first_name": "Suresh",
                "last_name": "Kumar",
                "email": "suresh.kumar@wehelp.org",
                "phone_number": "+919871122334",
                "employee_id": "AGT-2026-004",
                "assigned_area": "South Zone - Jayanagar",
                "is_active_agent": True
            },
            desc="Creates a new field agent credential for logging into the mobile APK."
        ),
        make_req(
            "Admin Get Agent Detail",
            "GET",
            "/api/admin/agents/{{agent_id}}/",
            auth_type="admin",
            desc="Fetches full profile and status for a specific field agent."
        ),
        make_req(
            "Admin Update Agent Account",
            "PUT",
            "/api/admin/agents/{{agent_id}}/",
            auth_type="admin",
            body={
                "username": "agent_rahul",
                "first_name": "Rahul",
                "last_name": "Sharma",
                "email": "rahul.sharma@wehelp.org",
                "phone_number": "+919876543210",
                "employee_id": "AGT-2026-001",
                "assigned_area": "East Zone - Koramangala",
                "is_active_agent": True
            },
            desc="Admin updates agent profile information and duty area."
        ),
        make_req(
            "Admin Deactivate / Delete Agent",
            "DELETE",
            "/api/admin/agents/{{agent_id}}/",
            auth_type="admin",
            desc="Deactivates or removes a field agent from the system."
        ),
        make_req(
            "Admin Toggle Agent Active Status",
            "POST",
            "/api/admin/agents/{{agent_id}}/toggle-status/",
            auth_type="admin",
            desc="Quickly activates or deactivates an agent's field permissions."
        )
    ]
}

# ==========================================
# 10. SYSTEM & DOCUMENTATION
# ==========================================
folder_system = {
    "name": "10. System & API Documentation",
    "description": "Root endpoint and interactive Swagger/OpenAPI documentation endpoints.",
    "item": [
        make_req(
            "API Root Catalog Index",
            "GET",
            "/",
            desc="Returns interactive JSON catalog of all API groups and documentation URLs."
        ),
        make_req(
            "OpenAPI 3.0 Schema (YAML / JSON)",
            "GET",
            "/api/schema/",
            desc="Returns machine-readable OpenAPI 3.0 specification."
        )
    ]
}

collection["item"] = [
    folder_auth,
    folder_dashboards,
    folder_tracking,
    folder_attendance,
    folder_targets,
    folder_donations,
    folder_payments,
    folder_leaves,
    folder_agents,
    folder_system
]

# Write collection to file
output_path = "e:/14-10-2026/WeHelp_Backend_API.postman_collection.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(collection, f, indent=2)

print(f"Postman collection successfully generated at: {output_path}")

# Generate Local Environment
local_env = {
    "id": "wehelp-env-local",
    "name": "WeHelp - Local Development",
    "values": [
        {"key": "baseUrl", "value": "http://127.0.0.1:8000", "type": "default", "enabled": True},
        {"key": "admin_username", "value": "admin", "type": "default", "enabled": True},
        {"key": "admin_password", "value": "admin123", "type": "secret", "enabled": True},
        {"key": "agent_username", "value": "agent_rahul", "type": "default", "enabled": True},
        {"key": "agent_password", "value": "agent123", "type": "secret", "enabled": True},
        {"key": "admin_token", "value": "", "type": "secret", "enabled": True},
        {"key": "agent_token", "value": "", "type": "secret", "enabled": True},
        {"key": "admin_refresh_token", "value": "", "type": "secret", "enabled": True},
        {"key": "agent_refresh_token", "value": "", "type": "secret", "enabled": True},
        {"key": "agent_id", "value": "1", "type": "default", "enabled": True},
        {"key": "donation_id", "value": "1", "type": "default", "enabled": True},
        {"key": "leave_id", "value": "1", "type": "default", "enabled": True},
        {"key": "target_id", "value": "1", "type": "default", "enabled": True}
    ]
}

with open("e:/14-10-2026/WeHelp_Local.postman_environment.json", "w", encoding="utf-8") as f:
    json.dump(local_env, f, indent=2)

# Generate Production/EC2 Environment
prod_env = {
    "id": "wehelp-env-prod",
    "name": "WeHelp - Production (AWS EC2)",
    "values": [
        {"key": "baseUrl", "value": "http://3.110.92.188", "type": "default", "enabled": True},
        {"key": "admin_username", "value": "admin", "type": "default", "enabled": True},
        {"key": "admin_password", "value": "admin123", "type": "secret", "enabled": True},
        {"key": "agent_username", "value": "agent_rahul", "type": "default", "enabled": True},
        {"key": "agent_password", "value": "agent123", "type": "secret", "enabled": True},
        {"key": "admin_token", "value": "", "type": "secret", "enabled": True},
        {"key": "agent_token", "value": "", "type": "secret", "enabled": True},
        {"key": "admin_refresh_token", "value": "", "type": "secret", "enabled": True},
        {"key": "agent_refresh_token", "value": "", "type": "secret", "enabled": True},
        {"key": "agent_id", "value": "1", "type": "default", "enabled": True},
        {"key": "donation_id", "value": "1", "type": "default", "enabled": True},
        {"key": "leave_id", "value": "1", "type": "default", "enabled": True},
        {"key": "target_id", "value": "1", "type": "default", "enabled": True}
    ]
}

with open("e:/14-10-2026/WeHelp_Production.postman_environment.json", "w", encoding="utf-8") as f:
    json.dump(prod_env, f, indent=2)

print("Environments generated successfully.")
