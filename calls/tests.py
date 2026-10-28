from decimal import Decimal
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from .models import CallLog, TelemarketingLead

User = get_user_model()


class TelemarketingCallsTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username="admin_test",
            password="Password@123",
            role="ADMIN",
            is_staff=True,
        )
        self.agent1 = User.objects.create_user(
            username="agent1_test",
            password="Password@123",
            role="AGENT",
            first_name="Rahul",
        )
        self.agent2 = User.objects.create_user(
            username="agent2_test",
            password="Password@123",
            role="AGENT",
            first_name="Priya",
        )

        self.lead = TelemarketingLead.objects.create(
            name="Suresh Kumar",
            phone_number="+919876543210",
            category="DONOR",
            status="NEW",
        )

    def test_agent_logs_call_successfully(self):
        """Agent can record a completed telemarketing call."""
        self.client.force_authenticate(user=self.agent1)
        url = reverse("agent-call-logs")
        payload = {
            "contact_name": "Suresh Kumar",
            "phone_number": "+919876543210",
            "call_type": "OUTGOING",
            "status": "DONATION_PLEDGED",
            "call_duration_seconds": 180,
            "pledged_amount": "2500.00",
            "notes": "Pledged 2500 for grocery kits",
            "lead_category": "DONOR",
        }
        res = self.client.post(url, payload)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn("call_log", res.data)
        self.assertEqual(res.data["call_log"]["contact_name"], "Suresh Kumar")
        self.assertEqual(res.data["call_log"]["agent_username"], "agent1_test")

        # Verify database record
        call_log = CallLog.objects.filter(contact_name="Suresh Kumar").first()
        self.assertIsNotNone(call_log)
        self.assertEqual(call_log.agent, self.agent1)
        self.assertEqual(call_log.pledged_amount, Decimal("2500.00"))

        # Verify lead status was updated to CONVERTED
        self.lead.refresh_from_db()
        self.assertEqual(self.lead.status, "CONVERTED")
        self.assertEqual(self.lead.total_calls_count, 1)

    def test_agent_retrieves_own_call_logs_only(self):
        """Agent should retrieve only their own call history."""
        # Create calls by agent 1 and agent 2
        CallLog.objects.create(
            agent=self.agent1,
            contact_name="Contact A",
            phone_number="+919800000001",
            status="CONNECTED",
            call_duration_seconds=60,
        )
        CallLog.objects.create(
            agent=self.agent2,
            contact_name="Contact B",
            phone_number="+919800000002",
            status="BUSY",
            call_duration_seconds=10,
        )

        self.client.force_authenticate(user=self.agent1)
        url = reverse("agent-call-logs")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)
        self.assertEqual(res.data[0]["contact_name"], "Contact A")

    def test_agent_retrieves_telemarketing_summary(self):
        """Agent retrieves today call counts and pledges."""
        CallLog.objects.create(
            agent=self.agent1,
            contact_name="Contact C",
            phone_number="+919800000003",
            status="DONATION_PLEDGED",
            call_duration_seconds=120,
            pledged_amount=Decimal("1500.00"),
        )
        self.client.force_authenticate(user=self.agent1)
        url = reverse("agent-call-summary")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["today_calls_count"], 1)
        self.assertEqual(res.data["today_pledged_amount"], 1500.0)

    def test_admin_retrieves_all_call_logs(self):
        """Admin can view call logs across all telemarketing staff."""
        CallLog.objects.create(
            agent=self.agent1,
            contact_name="Contact 1",
            phone_number="+919800000011",
            status="CONNECTED",
        )
        CallLog.objects.create(
            agent=self.agent2,
            contact_name="Contact 2",
            phone_number="+919800000022",
            status="INTERESTED",
        )

        self.client.force_authenticate(user=self.admin)
        url = reverse("admin-call-logs")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(res.data), 2)

    def test_admin_call_summary(self):
        """Admin retrieves consolidated performance analytics."""
        self.client.force_authenticate(user=self.admin)
        url = reverse("admin-call-summary")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("total_calls_all_time", res.data)
        self.assertIn("disposition_breakdown", res.data)
        self.assertIn("agent_performance_today", res.data)

    def test_agent_update_call_log_and_auto_complete_fields(self):
        """Verify Agent ID, Contact Number, and 30s duration auto-complete serialization."""
        call = CallLog.objects.create(
            agent=self.agent1,
            contact_name="Ramesh Sharma",
            phone_number="+919876543210",
            status="CONNECTED",
            call_duration_seconds=30,
            pledged_amount=Decimal("0.00"),
        )
        self.client.force_authenticate(user=self.agent1)
        url = reverse("agent-call-detail", kwargs={"pk": call.pk})

        # Test GET
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["agent_id"], self.agent1.id)
        self.assertEqual(res.data["phone_number"], "+919876543210")
        self.assertEqual(res.data["call_duration_seconds"], 30)
        self.assertEqual(res.data["formatted_duration"], "30s")

        # Test PATCH (e.g. updating notes or pledged amount)
        patch_res = self.client.patch(
            url,
            {"pledged_amount": "500.00", "notes": "Donor pledged 500"},
        )
        self.assertEqual(patch_res.status_code, status.HTTP_200_OK)
        call.refresh_from_db()
        self.assertEqual(call.pledged_amount, Decimal("500.00"))
        self.assertEqual(call.notes, "Donor pledged 500")
