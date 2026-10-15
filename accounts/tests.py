from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User


class AccountsWorkflowTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username="admin_test",
            password="Password@123",
            email="admin@test.com",
            role="ADMIN",
        )
        self.agent = User.objects.create_user(
            username="agent_test",
            password="Password@123",
            email="agent@test.com",
            role="AGENT",
            employee_id="AGT-001",
            assigned_area="Central Zone",
            is_active_agent=True,
        )
        self.login_url = reverse("auth-login")
        self.admin_agents_url = reverse("admin-agents-list-create")

    def test_admin_login_success(self):
        """Admin selects Admin role and provides valid credentials"""
        payload = {
            "username": "admin_test",
            "password": "Password@123",
            "role": "ADMIN",
        }
        res = self.client.post(self.login_url, payload)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("tokens", res.data)
        self.assertEqual(res.data["role"], "ADMIN")

    def test_agent_login_success(self):
        """Agent selects Agent role and enters assigned username and password"""
        payload = {
            "username": "agent_test",
            "password": "Password@123",
            "role": "AGENT",
        }
        res = self.client.post(self.login_url, payload)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("tokens", res.data)
        self.assertEqual(res.data["role"], "AGENT")

    def test_login_invalid_credentials_error(self):
        """Credentials Valid? -> No -> Show Login Error"""
        payload = {
            "username": "agent_test",
            "password": "WrongPassword",
            "role": "AGENT",
        }
        res = self.client.post(self.login_url, payload)
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("detail", res.data)

    def test_login_role_mismatch_error(self):
        """Attempting to log in as ADMIN with an AGENT account fails"""
        payload = {
            "username": "agent_test",
            "password": "Password@123",
            "role": "ADMIN",
        }
        res = self.client.post(self.login_url, payload)
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_admin_creates_agent_account(self):
        """Admin Workflow: Agent Creation -> Create Agent Username and Password -> Save Agent Account"""
        self.client.force_authenticate(user=self.admin)
        payload = {
            "username": "agent_newbie",
            "password": "SecretPassword123",
            "first_name": "Karan",
            "last_name": "Mehta",
            "email": "karan.mehta@test.com",
            "phone_number": "+91 9998887776",
            "employee_id": "AGT-999",
            "assigned_area": "East Delhi",
        }
        res = self.client.post(self.admin_agents_url, payload)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data["agent"]["username"], "agent_newbie")

        # Verify new agent can log in
        self.client.force_authenticate(user=None)
        login_res = self.client.post(
            self.login_url,
            {
                "username": "agent_newbie",
                "password": "SecretPassword123",
                "role": "AGENT",
            },
        )
        self.assertEqual(login_res.status_code, status.HTTP_200_OK)

    def test_admin_dashboard(self):
        self.client.force_authenticate(user=self.admin)
        res = self.client.get(reverse("admin-dashboard"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("metrics", res.data)

    def test_agent_dashboard(self):
        self.client.force_authenticate(user=self.agent)
        res = self.client.get(reverse("agent-dashboard"))
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("agent_profile", res.data)
        self.assertIn("attendance", res.data)
