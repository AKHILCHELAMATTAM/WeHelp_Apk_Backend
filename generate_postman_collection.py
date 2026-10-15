import json
import uuid

def build_postman_collection(base_url="http://127.0.0.1:8000", name="Field Agent & Donation Management System API"):
    collection = {
        "info": {
            "_postman_id": str(uuid.uuid4()),
            "name": name,
            "description": (
                f"# {name}\n\n"
                f"**Target URL:** `{base_url}`\n\n"
                "This Postman Collection covers the end-to-end workflow for both **Field Agents** and **Administrators** "
                "as defined in the workflow diagram:\n"
                "- **Authentication**: Role-based login (Admin/Agent) with JWT token auto-capture.\n"
                "- **Admin Workflow**: Agent Creation, Real-time GPS Location Tracking, Leave & Week-Off Management, "
                "Payment Records Management, and Daily Targets.\n"
                "- **Agent Workflow**: GPS Location Streaming, Cash & Product/Grocery Donation Logging, "
                "Attendance Check-In/Out, Daily Targets & Progress Tracking, and Leave Requests.\n\n"
                "### ⚡ Quick Start:\n"
                "1. Send the **Admin Login** request under `1. Authentication & Profile` to automatically set `{{admin_token}}`.\n"
                "2. Send the **Agent Login** request under `1. Authentication & Profile` to automatically set `{{agent_token}}`.\n"
                "3. You can now execute any Admin or Agent request in this collection seamlessly!"
            ),
            "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        },
        "variable": [
            {"key": "baseUrl", "value": base_url, "type": "string"},
            {"key": "admin_token", "value": "", "type": "string"},
            {"key": "agent_token", "value": "", "type": "string"},
            {"key": "refresh_token", "value": "", "type": "string"},
            {"key": "agent_id", "value": "2", "type": "string"},
            {"key": "donation_id", "value": "1", "type": "string"},
            {"key": "leave_id", "value": "1", "type": "string"},
            {"key": "target_id", "value": "1", "type": "string"}
        ],
        "item": []
    }

    # Helper functions
    def make_auth_header(token_var):
        return {
            "type": "bearer",
            "bearer": [{"key": "token", "value": f"{{{{{token_var}}}}}", "type": "string"}]
        }

    def make_request(name, method, url_path, query_params=None, body_data=None, token_var=None, test_script=None, description=""):
        path_segments = [p for p in url_path.split("/") if p]
        if url_path.endswith("/"):
            path_segments.append("")

        url_obj = {
            "raw": f"{{{{baseUrl}}}}/{url_path}" + (("?" + "&".join([f"{q['key']}={q['value']}" for q in query_params])) if query_params else ""),
            "host": ["{{baseUrl}}"],
            "path": path_segments
        }
        if query_params:
            url_obj["query"] = query_params

        req = {
            "name": name,
            "request": {
                "method": method,
                "header": [
                    {"key": "Accept", "value": "application/json", "type": "text"},
                    {"key": "Content-Type", "value": "application/json", "type": "text"}
                ],
                "url": url_obj,
                "description": description
            },
            "response": []
        }

        if token_var:
            req["request"]["auth"] = make_auth_header(token_var)

        if body_data is not None:
            req["request"]["body"] = {
                "mode": "raw",
                "raw": json.dumps(body_data, indent=2),
                "options": {"raw": {"language": "json"}}
            }

        if test_script:
            req["event"] = [{
                "listen": "test",
                "script": {
                    "exec": test_script.strip().split("\n"),
                    "type": "text/javascript"
                }
            }]

        return req

    # -------------------------------------------------------------
    # FOLDER 1: Authentication & Profile
    # -------------------------------------------------------------
    auth_folder = {
        "name": "1. Authentication & Profile",
        "description": "Role-based login for Admin and Agent, token refresh, and user profile management.",
        "item": [
            make_request(
                name="Admin Login (Auto-captures admin_token)",
                method="POST",
                url_path="api/auth/login/",
                body_data={
                    "username": "admin",
                    "password": "Admin@1234",
                    "role": "ADMIN"
                },
                test_script="""
if (pm.response.code === 200) {
    var jsonData = pm.response.json();
    if (jsonData.tokens && jsonData.tokens.access) {
        pm.collectionVariables.set("admin_token", jsonData.tokens.access);
        pm.collectionVariables.set("refresh_token", jsonData.tokens.refresh);
        console.log("Admin JWT access token captured successfully!");
    }
}
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});
pm.test("User role is ADMIN", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.role).to.eql("ADMIN");
});
""",
                description="Workflow: 'Select User Role' -> 'Admin' -> 'Admin Login' -> 'Credentials Valid?' -> Yes: 'Admin Dashboard'"
            ),
            make_request(
                name="Agent Login (Auto-captures agent_token)",
                method="POST",
                url_path="api/auth/login/",
                body_data={
                    "username": "agent_rahul",
                    "password": "Agent@1234",
                    "role": "AGENT"
                },
                test_script="""
if (pm.response.code === 200) {
    var jsonData = pm.response.json();
    if (jsonData.tokens && jsonData.tokens.access) {
        pm.collectionVariables.set("agent_token", jsonData.tokens.access);
        console.log("Agent JWT access token captured successfully!");
    }
}
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});
pm.test("User role is AGENT", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.role).to.eql("AGENT");
});
""",
                description="Workflow: 'Select User Role' -> 'Agent' -> 'Agent Login' -> 'Credentials Valid?' -> Yes: 'Agent Dashboard'"
            ),
            make_request(
                name="Invalid Credentials Test (Credentials Valid? -> No)",
                method="POST",
                url_path="api/auth/login/",
                body_data={
                    "username": "agent_rahul",
                    "password": "WrongPassword@999",
                    "role": "AGENT"
                },
                test_script="""
pm.test("Status code is 400 Bad Request", function () {
    pm.response.to.have.status(400);
});
pm.test("Response contains error detail", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property("detail");
});
""",
                description="Workflow: 'Credentials Valid?' -> No -> 'Show Login Error'"
            ),
            make_request(
                name="Refresh JWT Token",
                method="POST",
                url_path="api/auth/token/refresh/",
                body_data={
                    "refresh": "{{refresh_token}}"
                },
                description="Refreshes an expired JWT access token using the refresh token."
            ),
            make_request(
                name="Get Logged-in User Profile",
                method="GET",
                url_path="api/auth/profile/",
                token_var="admin_token",
                description="Retrieves the profile of the currently authenticated user."
            ),
            make_request(
                name="Update User Profile",
                method="PATCH",
                url_path="api/auth/profile/",
                token_var="agent_token",
                body_data={
                    "first_name": "Rahul",
                    "last_name": "Sharma",
                    "phone_number": "+91 9811223399"
                },
                description="Allows the authenticated user to update their contact details."
            )
        ]
    }

    # -------------------------------------------------------------
    # FOLDER 2: Admin Workflow
    # -------------------------------------------------------------
    admin_folder = {
        "name": "2. Admin Workflow",
        "description": "All management APIs available to Administrator from the Admin Dashboard.",
        "item": [
            {
                "name": "Admin Dashboard",
                "item": [
                    make_request(
                        name="Get Admin Dashboard Overview",
                        method="GET",
                        url_path="api/admin/dashboard/",
                        token_var="admin_token",
                        description="Workflow: 'Admin Dashboard' - Returns aggregated metrics for total agents, online agents, collections, pending leaves, and recent activity."
                    )
                ]
            },
            {
                "name": "Agent Creation & Management",
                "item": [
                    make_request(
                        name="Create Field Agent Account (Auto-captures agent_id)",
                        method="POST",
                        url_path="api/admin/agents/",
                        token_var="admin_token",
                        body_data={
                            "username": "agent_vikram",
                            "password": "Agent@123456",
                            "first_name": "Vikram",
                            "last_name": "Aditya",
                            "email": "vikram.aditya@ngo-foundation.org",
                            "phone_number": "+91 9899112233",
                            "employee_id": "AGT-2026-003",
                            "assigned_area": "West Zone - Janakpuri, New Delhi",
                            "is_active_agent": True
                        },
                        test_script="""
if (pm.response.code === 201) {
    var jsonData = pm.response.json();
    if (jsonData.agent && jsonData.agent.id) {
        pm.collectionVariables.set("agent_id", jsonData.agent.id);
        console.log("Created agent ID captured: " + jsonData.agent.id);
    }
}
pm.test("Status code is 201 Created", function () {
    pm.response.to.have.status(201);
});
""",
                        description="Workflow: 'Admin Dashboard' -> 'Agent Creation' -> 'Create Agent Username and Password' -> 'Save Agent Account'"
                    ),
                    make_request(
                        name="List All Field Agents (with filter & search)",
                        method="GET",
                        url_path="api/admin/agents/",
                        query_params=[
                            {"key": "search", "value": "Rahul", "disabled": True},
                            {"key": "is_active", "value": "true", "disabled": True}
                        ],
                        token_var="admin_token",
                        description="Lists all field agents with optional search and active status filters."
                    ),
                    make_request(
                        name="Get Agent Detail",
                        method="GET",
                        url_path="api/admin/agents/{{agent_id}}/",
                        token_var="admin_token",
                        description="Retrieves profile and assignment details for a specific agent."
                    ),
                    make_request(
                        name="Update Agent Profile / Territory",
                        method="PATCH",
                        url_path="api/admin/agents/{{agent_id}}/",
                        token_var="admin_token",
                        body_data={
                            "assigned_area": "Central Zone - Connaught Place & Karol Bagh",
                            "phone_number": "+91 9899112200"
                        },
                        description="Updates territory or contact info for an agent."
                    ),
                    make_request(
                        name="Toggle Agent Active / Inactive Status",
                        method="POST",
                        url_path="api/admin/agents/{{agent_id}}/toggle-status/",
                        token_var="admin_token",
                        description="Activates or deactivates field duty privileges for the agent."
                    )
                ]
            },
            {
                "name": "Agent Location Tracking",
                "item": [
                    make_request(
                        name="View Live Agent Locations on Map",
                        method="GET",
                        url_path="api/admin/tracking/live/",
                        token_var="admin_token",
                        description="Workflow: 'Agent Location Tracking' -> 'View Agent Location on Map' -> 'View Latitude Longitude and Location'\nReturns latest GPS coordinates, battery level, address, and online status for all field agents."
                    ),
                    make_request(
                        name="View Agent Breadcrumb Route History",
                        method="GET",
                        url_path="api/admin/tracking/agents/{{agent_id}}/history/",
                        query_params=[
                            {"key": "date", "value": "2026-10-14", "description": "Filter by date (YYYY-MM-DD)"}
                        ],
                        token_var="admin_token",
                        description="Workflow: 'View Latitude Longitude and Location' - Retrieves chronological GPS breadcrumb history for an agent on a specific date."
                    )
                ]
            },
            {
                "name": "Payment Details & Records Management",
                "item": [
                    make_request(
                        name="View Payment Records (Cash Transactions)",
                        method="GET",
                        url_path="api/admin/payments/records/",
                        query_params=[
                            {"key": "payment_mode", "value": "UPI", "disabled": True},
                            {"key": "payment_status", "value": "COMPLETED", "disabled": True},
                            {"key": "agent_id", "value": "{{agent_id}}", "disabled": True},
                            {"key": "date", "value": "2026-10-14", "disabled": True}
                        ],
                        token_var="admin_token",
                        description="Workflow: 'Payment Details' -> 'View or Manage Payment Records'\nLists cash donations, settlement statuses, and payment reference numbers."
                    ),
                    make_request(
                        name="Manage Payment Record / Settlement Status",
                        method="PATCH",
                        url_path="api/admin/payments/records/{{donation_id}}/",
                        token_var="admin_token",
                        body_data={
                            "payment_status": "COMPLETED",
                            "transaction_reference": "BANK-TXN-REF-998822",
                            "notes": "Verified and reconciled with bank statement"
                        },
                        description="Workflow: 'Manage Payment Records' - Updates transaction settlement status and bank reference."
                    ),
                    make_request(
                        name="Get Payment Financial Summary",
                        method="GET",
                        url_path="api/admin/payments/summary/",
                        token_var="admin_token",
                        description="Returns total collections, breakdown by payment mode (UPI, Cash, Card, NEFT), and settlement status."
                    )
                ]
            },
            {
                "name": "Donation Records Management",
                "item": [
                    make_request(
                        name="List All Donations (Cash & Products)",
                        method="GET",
                        url_path="api/admin/donations/",
                        query_params=[
                            {"key": "donation_type", "value": "CASH", "disabled": True},
                            {"key": "search", "value": "Ramesh", "disabled": True},
                            {"key": "date", "value": "2026-10-14", "disabled": True}
                        ],
                        token_var="admin_token",
                        description="Lists all donations collected by all agents with multi-criteria filtering."
                    ),
                    make_request(
                        name="Get Donation Detail & Receipt",
                        method="GET",
                        url_path="api/admin/donations/{{donation_id}}/",
                        token_var="admin_token",
                        description="Retrieves full donation record including donor details, product/cash values, and receipt number."
                    ),
                    make_request(
                        name="Verify Donation Record",
                        method="POST",
                        url_path="api/admin/donations/{{donation_id}}/verify/",
                        token_var="admin_token",
                        description="Admin marks donation status as 'VERIFIED'."
                    )
                ]
            },
            {
                "name": "Leave and Week-Off Management",
                "item": [
                    make_request(
                        name="View Agent Requests",
                        method="GET",
                        url_path="api/admin/leaves/",
                        query_params=[
                            {"key": "status", "value": "PENDING", "disabled": True},
                            {"key": "request_type", "value": "LEAVE", "disabled": True}
                        ],
                        token_var="admin_token",
                        description="Workflow: 'Leave and Week-Off Management' -> 'View Agent Requests'\nLists all leave and week-off requests submitted by agents."
                    ),
                    make_request(
                        name="Get Leave Request Detail",
                        method="GET",
                        url_path="api/admin/leaves/{{leave_id}}/",
                        token_var="admin_token",
                        description="Retrieves detailed information of an agent's leave or week-off request."
                    ),
                    make_request(
                        name="Approve Request (Approve Leave or Week-Off)",
                        method="POST",
                        url_path="api/admin/leaves/{{leave_id}}/review/",
                        token_var="admin_token",
                        body_data={
                            "action": "APPROVE",
                            "admin_remarks": "Approved as per monthly duty schedule. Please ensure pending donor receipts are uploaded."
                        },
                        description="Workflow: 'Approve Request?' -> Yes: 'Approve Leave or Week-Off'"
                    ),
                    make_request(
                        name="Reject Request",
                        method="POST",
                        url_path="api/admin/leaves/{{leave_id}}/review/",
                        token_var="admin_token",
                        body_data={
                            "action": "REJECT",
                            "admin_remarks": "Request cannot be approved due to high-priority field donation drive scheduled on these dates."
                        },
                        description="Workflow: 'Approve Request?' -> No: 'Reject Request'"
                    )
                ]
            },
            {
                "name": "Daily Targets & Attendance Monitoring",
                "item": [
                    make_request(
                        name="Assign Daily Target to Agent",
                        method="POST",
                        url_path="api/admin/targets/",
                        token_var="admin_token",
                        body_data={
                            "agent": 2,
                            "date": "2026-10-14",
                            "target_cash_amount": "12000.00",
                            "target_donations_count": 8,
                            "target_product_units": "60.00",
                            "notes": "Focus on high-density residential housing societies"
                        },
                        test_script="""
if (pm.response.code === 201) {
    var jsonData = pm.response.json();
    if (jsonData.id) {
        pm.collectionVariables.set("target_id", jsonData.id);
    }
}
""",
                        description="Sets daily goals for an agent to display on their mobile app dashboard."
                    ),
                    make_request(
                        name="List All Daily Targets",
                        method="GET",
                        url_path="api/admin/targets/",
                        query_params=[
                            {"key": "date", "value": "2026-10-14", "disabled": True}
                        ],
                        token_var="admin_token",
                        description="Lists targets assigned across field staff."
                    ),
                    make_request(
                        name="View All Agents Attendance Records",
                        method="GET",
                        url_path="api/admin/attendance/",
                        query_params=[
                            {"key": "date", "value": "2026-10-14", "disabled": True},
                            {"key": "status", "value": "PRESENT", "disabled": True}
                        ],
                        token_var="admin_token",
                        description="Monitors check-in/out times, statuses, and locations for field agents."
                    )
                ]
            }
        ]
    }

    # -------------------------------------------------------------
    # FOLDER 3: Agent Workflow
    # -------------------------------------------------------------
    agent_folder = {
        "name": "3. Agent Workflow",
        "description": "All endpoints used by the field agent from the Android App.",
        "item": [
            {
                "name": "Agent Dashboard",
                "item": [
                    make_request(
                        name="Get Agent Dashboard Overview",
                        method="GET",
                        url_path="api/agent/dashboard/",
                        token_var="agent_token",
                        description="Workflow: 'Agent Dashboard' - Returns agent profile, attendance status, today's targets & progress, today's collection summary, and latest leave request status."
                    )
                ]
            },
            {
                "name": "Access Location (GPS Tracking)",
                "item": [
                    make_request(
                        name="Send Location to Backend",
                        method="POST",
                        url_path="api/agent/location/",
                        token_var="agent_token",
                        body_data={
                            "latitude": 28.7048,
                            "longitude": 77.1035,
                            "accuracy": 3.8,
                            "speed": 2.5,
                            "battery_level": 84,
                            "address": "Sector 14 Main Road, Rohini, Delhi"
                        },
                        description="Workflow: 'Access Location' -> 'Request GPS Permission if Needed' -> 'Capture Agent Location' -> 'Send Location to Backend' -> 'Admin Can Track Agent'"
                    ),
                    make_request(
                        name="Get Latest Recorded Location",
                        method="GET",
                        url_path="api/agent/location/latest/",
                        token_var="agent_token",
                        description="Retrieves the agent's most recently uploaded GPS coordinates."
                    )
                ]
            },
            {
                "name": "Donation Entry",
                "item": [
                    make_request(
                        name="Enter Cash Donation (Auto-captures donation_id)",
                        method="POST",
                        url_path="api/agent/donations/cash/",
                        token_var="agent_token",
                        body_data={
                            "donor_name": "Suresh Raina",
                            "donor_phone": "+91 9876501234",
                            "donor_email": "suresh.raina@example.com",
                            "donor_address": "House 45, Sector 15, Rohini, New Delhi",
                            "amount": "4000.00",
                            "currency": "INR",
                            "payment_mode": "UPI",
                            "transaction_reference": "UPI/9988771122/REF",
                            "notes": "Contribution for child nutrition drive",
                            "latitude": 28.7049,
                            "longitude": 77.1036
                        },
                        test_script="""
if (pm.response.code === 201) {
    var jsonData = pm.response.json();
    if (jsonData.donation && jsonData.donation.id) {
        pm.collectionVariables.set("donation_id", jsonData.donation.id);
        console.log("Captured created donation ID: " + jsonData.donation.id);
    }
}
pm.test("Status code is 201 Created", function () {
    pm.response.to.have.status(201);
});
pm.test("Receipt number generated", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.donation.receipt_number).to.be.a("string");
});
""",
                        description="Workflow: 'Donation Entry' -> 'Donation Type' -> 'Cash' -> 'Enter Cash Donation' -> 'Save Donation Record'"
                    ),
                    make_request(
                        name="Enter Product or Grocery Donation",
                        method="POST",
                        url_path="api/agent/donations/product/",
                        token_var="agent_token",
                        body_data={
                            "donor_name": "Shree Ram Supermarket",
                            "donor_phone": "+91 9811224455",
                            "donor_email": "contact@shreeramsupermarket.com",
                            "donor_address": "Shop 12, Market Complex, Sector 14, Delhi",
                            "product_name": "Wheat Flour & Lentil Packets",
                            "product_category": "Grocery",
                            "quantity": "40.00",
                            "unit": "kg",
                            "estimated_value": "2400.00",
                            "notes": "Flood relief grocery support",
                            "latitude": 28.7051,
                            "longitude": 77.1039
                        },
                        test_script="""
pm.test("Status code is 201 Created", function () {
    pm.response.to.have.status(201);
});
pm.test("Donation type is PRODUCT", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.donation.donation_type).to.eql("PRODUCT");
});
""",
                        description="Workflow: 'Donation Entry' -> 'Donation Type' -> 'Products' -> 'Enter Product or Grocery Donation' -> 'Save Donation Record'"
                    ),
                    make_request(
                        name="List Own Donations",
                        method="GET",
                        url_path="api/agent/donations/",
                        query_params=[
                            {"key": "donation_type", "value": "CASH", "disabled": True},
                            {"key": "date", "value": "2026-10-14", "disabled": True}
                        ],
                        token_var="agent_token",
                        description="Lists all donations collected by the logged-in agent."
                    ),
                    make_request(
                        name="Get Donation Detail & Receipt",
                        method="GET",
                        url_path="api/agent/donations/{{donation_id}}/",
                        token_var="agent_token",
                        description="Retrieves a specific donation record with receipt number and donor details."
                    ),
                    make_request(
                        name="Update Donation Details",
                        method="PATCH",
                        url_path="api/agent/donations/{{donation_id}}/",
                        token_var="agent_token",
                        body_data={
                            "donor_name": "Suresh Raina (Updated)",
                            "notes": "Donor requested receipt via SMS as well"
                        },
                        description="Workflow: 'Save Donation Record' -> 'Update Donation Details'"
                    ),
                    make_request(
                        name="Get Today's Donations Summary",
                        method="GET",
                        url_path="api/agent/donations/summary/",
                        token_var="agent_token",
                        description="Returns total cash collected, cash entries count, and product quantities collected today."
                    )
                ]
            },
            {
                "name": "Attendance & Daily Targets",
                "item": [
                    make_request(
                        name="Attendance Check-In",
                        method="POST",
                        url_path="api/agent/attendance/check-in/",
                        token_var="agent_token",
                        body_data={
                            "latitude": 28.7041,
                            "longitude": 77.1025,
                            "address": "Sector 14 Hub, Rohini, New Delhi",
                            "notes": "Starting morning field shift"
                        },
                        description="Workflow: 'Attendance' - Agent checks in for field duty with GPS location and address."
                    ),
                    make_request(
                        name="Attendance Check-Out",
                        method="POST",
                        url_path="api/agent/attendance/check-out/",
                        token_var="agent_token",
                        body_data={
                            "latitude": 28.7055,
                            "longitude": 77.1040,
                            "address": "Sector 14 Field Office, Delhi",
                            "notes": "Completed day schedule and submitted receipts"
                        },
                        description="Workflow: 'Attendance' - Agent checks out at end of shift with GPS location."
                    ),
                    make_request(
                        name="Get Today's Attendance Status",
                        method="GET",
                        url_path="api/agent/attendance/status/",
                        token_var="agent_token",
                        description="Returns check-in/out status, times, and coordinates for today."
                    ),
                    make_request(
                        name="Get Attendance History",
                        method="GET",
                        url_path="api/agent/attendance/history/",
                        token_var="agent_token",
                        description="Retrieves historical attendance records for the agent."
                    ),
                    make_request(
                        name="Display Today's Target / View Daily Target",
                        method="GET",
                        url_path="api/agent/target/today/",
                        token_var="agent_token",
                        test_script="""
pm.test("Status code is 200 OK", function () {
    pm.response.to.have.status(200);
});
pm.test("Target progress metrics present", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property("target_cash_amount");
    pm.expect(jsonData).to.have.property("achieved_cash_amount");
    pm.expect(jsonData).to.have.property("cash_completion_percentage");
});
""",
                        description="Workflow: 'Attendance' -> 'Display Today's Target' -> 'View Daily Target'\nReturns today's target goals alongside real-time achieved cash, product units, and completion percentage."
                    )
                ]
            },
            {
                "name": "Leave or Week-Off Request",
                "item": [
                    make_request(
                        name="Submit Leave or Week-Off Request (Auto-captures leave_id)",
                        method="POST",
                        url_path="api/agent/leaves/",
                        token_var="agent_token",
                        body_data={
                            "request_type": "LEAVE",
                            "start_date": "2026-10-20",
                            "end_date": "2026-10-21",
                            "reason": "Personal medical checkup"
                        },
                        test_script="""
if (pm.response.code === 201) {
    var jsonData = pm.response.json();
    if (jsonData.request && jsonData.request.id) {
        pm.collectionVariables.set("leave_id", jsonData.request.id);
        console.log("Captured leave request ID: " + jsonData.request.id);
    }
}
pm.test("Status code is 201 Created", function () {
    pm.response.to.have.status(201);
});
pm.test("Request status is PENDING", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.request.status).to.eql("PENDING");
});
""",
                        description="Workflow: 'Leave or Week-Off Request' -> 'Submit Request to Admin'"
                    ),
                    make_request(
                        name="View Approval or Rejection Status",
                        method="GET",
                        url_path="api/agent/leaves/",
                        query_params=[
                            {"key": "status", "value": "PENDING", "disabled": True},
                            {"key": "request_type", "value": "LEAVE", "disabled": True}
                        ],
                        token_var="agent_token",
                        description="Workflow: 'Submit Request to Admin' -> 'Admin Reviews Request' -> 'Approval or Rejection Status' -> 'Agent Dashboard'"
                    ),
                    make_request(
                        name="Get Leave Request Detail",
                        method="GET",
                        url_path="api/agent/leaves/{{leave_id}}/",
                        token_var="agent_token",
                        description="Retrieves a specific leave request submitted by the agent."
                    )
                ]
            }
        ]
    }

    collection["item"].append(auth_folder)
    collection["item"].append(admin_folder)
    collection["item"].append(agent_folder)

    return collection

def build_postman_environment(base_url="http://127.0.0.1:8000", name="Field Agent & Donation System - Local Environment"):
    return {
        "id": str(uuid.uuid4()),
        "name": name,
        "values": [
            {
                "key": "baseUrl",
                "value": base_url,
                "type": "default",
                "enabled": True
            },
            {
                "key": "admin_token",
                "value": "",
                "type": "secret",
                "enabled": True
            },
            {
                "key": "agent_token",
                "value": "",
                "type": "secret",
                "enabled": True
            },
            {
                "key": "refresh_token",
                "value": "",
                "type": "secret",
                "enabled": True
            },
            {
                "key": "agent_id",
                "value": "2",
                "type": "default",
                "enabled": True
            },
            {
                "key": "donation_id",
                "value": "1",
                "type": "default",
                "enabled": True
            },
            {
                "key": "leave_id",
                "value": "1",
                "type": "default",
                "enabled": True
            },
            {
                "key": "target_id",
                "value": "1",
                "type": "default",
                "enabled": True
            }
        ],
        "_postman_variable_scope": "environment"
    }

if __name__ == "__main__":
    # 1. Local Environment & Collection
    local_col = build_postman_collection(
        base_url="http://127.0.0.1:8000",
        name="Field Agent & Donation System API (Local)"
    )
    local_env = build_postman_environment(
        base_url="http://127.0.0.1:8000",
        name="Field Agent & Donation System - Local Environment"
    )

    with open("field_agent_api.postman_collection.json", "w", encoding="utf-8") as f:
        json.dump(local_col, f, indent=2, ensure_ascii=False)
    with open("field_agent_environment.postman_environment.json", "w", encoding="utf-8") as f:
        json.dump(local_env, f, indent=2, ensure_ascii=False)

    # 2. Render Production Environment & Collection
    render_url = "https://wehelp-apk-backend.onrender.com"
    render_col = build_postman_collection(
        base_url=render_url,
        name="WeHelp APK Backend API (Render)"
    )
    render_env = build_postman_environment(
        base_url=render_url,
        name="WeHelp APK Backend - Render Environment"
    )

    with open("wehelp_render_api.postman_collection.json", "w", encoding="utf-8") as f:
        json.dump(render_col, f, indent=2, ensure_ascii=False)
    with open("wehelp_render_environment.postman_environment.json", "w", encoding="utf-8") as f:
        json.dump(render_env, f, indent=2, ensure_ascii=False)

    print("Successfully generated both Local and Render Postman Collections and Environments!")
