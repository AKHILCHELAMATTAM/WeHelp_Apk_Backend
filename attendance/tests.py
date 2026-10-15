from decimal import Decimal
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from attendance.models import Attendance, DailyTarget
from donations.models import Donation


class AttendanceWorkflowTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username="admin_att",
            password="Password@123",
            role="ADMIN",
        )
        self.agent = User.objects.create_user(
            username="agent_att",
            password="Password@123",
            role="AGENT",
            employee_id="AGT-ATT-01",
        )
        self.check_in_url = reverse("agent-check-in")
        self.check_out_url = reverse("agent-check-out")
        self.target_url = reverse("agent-target-today")

    def test_agent_check_in_and_check_out(self):
        """Workflow: Attendance Check-In and Check-Out"""
        self.client.force_authenticate(user=self.agent)

        # 1. Check in
        check_in_payload = {
            "latitude": 28.5355,
            "longitude": 77.3910,
            "accuracy": 4.5,
            "address": "Sector 62 Metro Station, Noida",
            "notes": "Starting morning shift",
        }
        res = self.client.post(self.check_in_url, check_in_payload)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        # Direct response fields
        self.assertEqual(res.data["latitude"], 28.5355)
        self.assertEqual(res.data["longitude"], 77.3910)
        self.assertIn("https://www.google.com/maps?q=28.5355,77.391", res.data["google_map_link"])
        # Serializer fields
        self.assertIn("check_in_google_map_link", res.data["attendance"])
        self.assertIn("https://www.google.com/maps?q=28.5355,77.391", res.data["attendance"]["google_map_link"])
        today = timezone.localdate()
        att = Attendance.objects.get(agent=self.agent, date=today)
        self.assertIsNotNone(att.check_in_time)
        self.assertEqual(att.check_in_latitude, 28.5355)
        self.assertEqual(att.check_in_longitude, 77.3910)
        self.assertEqual(att.check_in_accuracy, 4.5)
        self.assertEqual(att.check_in_address, "Sector 62 Metro Station, Noida")
        self.assertIn("https://www.google.com/maps?q=28.5355,77.391", att.check_in_google_map_link)

        # 2. Check out
        check_out_payload = {
            "latitude": 28.5358,
            "longitude": 77.3915,
            "accuracy": 3.8,
            "address": "Sector 62 Office, Noida",
            "notes": "Completed day targets",
        }
        res = self.client.post(self.check_out_url, check_out_payload)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["latitude"], 28.5358)
        self.assertEqual(res.data["longitude"], 77.3915)
        self.assertIn("https://www.google.com/maps?q=28.5358,77.3915", res.data["google_map_link"])
        self.assertIn("check_out_google_map_link", res.data["attendance"])
        self.assertIn("https://www.google.com/maps?q=28.5358,77.3915", res.data["attendance"]["check_out_google_map_link"])
        att.refresh_from_db()
        self.assertIsNotNone(att.check_out_time)
        self.assertEqual(att.check_out_latitude, 28.5358)
        self.assertEqual(att.check_out_longitude, 77.3915)
        self.assertEqual(att.check_out_accuracy, 3.8)
        self.assertIn("https://www.google.com/maps?q=28.5358,77.3915", att.check_out_google_map_link)

    def test_view_daily_target_and_achieved_progress(self):
        """Workflow: Attendance -> Display Today's Target -> View Daily Target"""
        today = timezone.localdate()
        # Admin assigns target
        DailyTarget.objects.create(
            agent=self.agent,
            date=today,
            target_cash_amount=Decimal("10000.00"),
            target_donations_count=5,
            target_product_units=Decimal("20.00"),
            assigned_by=self.admin,
        )

        # Agent collects a cash donation today
        Donation.objects.create(
            agent=self.agent,
            donation_type="CASH",
            donor_name="Local Donor",
            amount=Decimal("5000.00"),
            created_at=timezone.now(),
        )

        self.client.force_authenticate(user=self.agent)
        res = self.client.get(self.target_url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(float(res.data["target_cash_amount"]), 10000.00)
        self.assertEqual(float(res.data["achieved_cash_amount"]), 5000.00)
        self.assertEqual(res.data["cash_completion_percentage"], 50.0)
        self.assertEqual(res.data["achieved_donations_count"], 1)
        self.assertFalse(res.data["is_cash_target_met"])
