from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from tracking.models import AgentLocation


class TrackingWorkflowTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username="admin_tracker",
            password="Password@123",
            role="ADMIN",
        )
        self.agent = User.objects.create_user(
            username="agent_geo",
            password="Password@123",
            role="AGENT",
            employee_id="AGT-GEO-01",
        )
        self.send_loc_url = reverse("agent-send-location")
        self.live_tracking_url = reverse("admin-tracking-live")

    def test_agent_sends_location(self):
        """Workflow: Capture Agent Location -> Send Location to Backend"""
        self.client.force_authenticate(user=self.agent)
        payload = {
            "latitude": 28.6139,
            "longitude": 77.2090,
            "accuracy": 3.2,
            "speed": 15.4,
            "battery_level": 82,
            "address": "Connaught Place, Central Delhi",
        }
        res = self.client.post(self.send_loc_url, payload)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(AgentLocation.objects.count(), 1)
        loc = AgentLocation.objects.first()
        self.assertEqual(loc.latitude, 28.6139)
        self.assertEqual(loc.agent, self.agent)

    def test_admin_live_location_tracking(self):
        """Workflow: Admin Can Track Agent -> View Agent Location on Map -> View Latitude Longitude and Location"""
        # Create a location record for agent
        AgentLocation.objects.create(
            agent=self.agent,
            latitude=28.6139,
            longitude=77.2090,
            accuracy=5.0,
            battery_level=90,
            address="Connaught Place, Central Delhi",
        )

        self.client.force_authenticate(user=self.admin)
        res = self.client.get(self.live_tracking_url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(len(res.data) >= 1)
        agent_data = next((a for a in res.data if a["agent_id"] == self.agent.id), None)
        self.assertIsNotNone(agent_data)
        self.assertEqual(agent_data["latitude"], 28.6139)
        self.assertEqual(agent_data["longitude"], 77.2090)
        self.assertEqual(agent_data["address"], "Connaught Place, Central Delhi")
