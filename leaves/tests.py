from datetime import timedelta
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from leaves.models import LeaveRequest


class LeavesWorkflowTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username="admin_leaves",
            password="Password@123",
            role="ADMIN",
        )
        self.agent = User.objects.create_user(
            username="agent_leaves",
            password="Password@123",
            role="AGENT",
            employee_id="AGT-LEV-01",
        )
        self.agent_leaves_url = reverse("agent-leaves-list-create")
        self.admin_leaves_url = reverse("admin-leaves-list")

    def test_agent_submits_leave_request(self):
        """Workflow: Leave or Week-Off Request -> Submit Request to Admin"""
        self.client.force_authenticate(user=self.agent)
        today = timezone.localdate()
        payload = {
            "request_type": "LEAVE",
            "start_date": str(today + timedelta(days=2)),
            "end_date": str(today + timedelta(days=3)),
            "reason": "Personal medical appointment",
        }
        res = self.client.post(self.agent_leaves_url, payload)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(LeaveRequest.objects.count(), 1)
        leave = LeaveRequest.objects.first()
        self.assertEqual(leave.status, "PENDING")
        self.assertEqual(leave.total_days, 2)
        self.assertEqual(leave.agent, self.agent)

    def test_admin_approves_request(self):
        """Workflow: Admin Reviews Request -> Approve Request? -> Yes: Approve Leave or Week-Off"""
        today = timezone.localdate()
        leave = LeaveRequest.objects.create(
            agent=self.agent,
            request_type="WEEK_OFF",
            start_date=today + timedelta(days=1),
            end_date=today + timedelta(days=1),
            total_days=1,
            reason="Weekly rest day",
            status="PENDING",
        )

        self.client.force_authenticate(user=self.admin)
        review_url = reverse("admin-leaves-review", kwargs={"pk": leave.id})
        res = self.client.post(
            review_url,
            {"action": "APPROVE", "admin_remarks": "Approved as per duty roster"},
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        leave.refresh_from_db()
        self.assertEqual(leave.status, "APPROVED")
        self.assertEqual(leave.admin_remarks, "Approved as per duty roster")
        self.assertEqual(leave.reviewed_by, self.admin)
        self.assertIsNotNone(leave.reviewed_at)

    def test_admin_rejects_request(self):
        """Workflow: Admin Reviews Request -> Approve Request? -> No: Reject Request"""
        today = timezone.localdate()
        leave = LeaveRequest.objects.create(
            agent=self.agent,
            request_type="LEAVE",
            start_date=today + timedelta(days=1),
            end_date=today + timedelta(days=2),
            total_days=2,
            reason="Holiday trip",
            status="PENDING",
        )

        self.client.force_authenticate(user=self.admin)
        review_url = reverse("admin-leaves-review", kwargs={"pk": leave.id})
        res = self.client.post(
            review_url,
            {
                "action": "REJECT",
                "admin_remarks": "High priority donation drive scheduled on these dates.",
            },
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        leave.refresh_from_db()
        self.assertEqual(leave.status, "REJECTED")

        # Agent checks 'Approval or Rejection Status'
        self.client.force_authenticate(user=self.agent)
        agent_res = self.client.get(self.agent_leaves_url)
        self.assertEqual(agent_res.status_code, status.HTTP_200_OK)
        req_item = agent_res.data["results"][0]
        self.assertEqual(req_item["status"], "REJECTED")
        self.assertEqual(
            req_item["admin_remarks"],
            "High priority donation drive scheduled on these dates.",
        )
