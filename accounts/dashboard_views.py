from datetime import timedelta
from decimal import Decimal
from django.contrib.auth import get_user_model
from django.db.models import Count, Sum
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from attendance.models import Attendance, DailyTarget
from attendance.serializers import AgentDailyTargetProgressSerializer
from calls.models import CallLog
from calls.serializers import CallLogSerializer
from donations.models import Donation
from donations.serializers import DonationDetailSerializer
from leaves.models import LeaveRequest
from leaves.serializers import LeaveRequestDetailSerializer
from tracking.models import AgentLocation
from .permissions import IsAdminUserRole, IsAgentUserRole

User = get_user_model()


class AdminDashboardView(APIView):
    """
    Consolidated analytics and metrics for the Admin Dashboard.
    Matches workflow node: 'Admin Dashboard'
    """

    permission_classes = [IsAdminUserRole]

    @extend_schema(
        responses={200: serializers.DictField()},
        description="Returns top-level overview metrics, online agents, pending leaves, and recent donations for Admin Dashboard.",
    )
    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        fifteen_mins_ago = timezone.now() - timedelta(minutes=15)

        # Agent metrics
        total_agents = User.objects.filter(role="AGENT").count()
        active_agents = User.objects.filter(role="AGENT", is_active_agent=True).count()
        present_today = Attendance.objects.filter(date=today, check_in_time__isnull=False).count()

        # Online agents (location updated within last 15 minutes)
        recent_locations = AgentLocation.objects.filter(
            recorded_at__gte=fifteen_mins_ago
        ).values_list("agent_id", flat=True)
        online_agents_count = len(set(recent_locations))

        # Financial & Donation metrics
        today_cash = (
            Donation.objects.filter(
                donation_type="CASH",
                payment_status="COMPLETED",
                created_at__date=today,
            ).aggregate(total=Sum("amount"))["total"]
            or Decimal("0.00")
        )

        all_time_cash = (
            Donation.objects.filter(
                donation_type="CASH", payment_status="COMPLETED"
            ).aggregate(total=Sum("amount"))["total"]
            or Decimal("0.00")
        )

        today_cash_count = Donation.objects.filter(
            donation_type="CASH", created_at__date=today
        ).count()

        today_product_count = Donation.objects.filter(
            donation_type="PRODUCT", created_at__date=today
        ).count()

        today_product_quantity = (
            Donation.objects.filter(
                donation_type="PRODUCT", created_at__date=today
            ).aggregate(total=Sum("quantity"))["total"]
            or Decimal("0.00")
        )

        all_time_donations_count = Donation.objects.count()

        # Telemarketing call metrics
        today_calls_count = CallLog.objects.filter(created_at__date=today).count()
        today_calls_connected = CallLog.objects.filter(
            created_at__date=today,
            status__in=["CONNECTED", "INTERESTED", "DONATION_PLEDGED"],
        ).count()
        today_calls_pledged = (
            CallLog.objects.filter(created_at__date=today).aggregate(total=Sum("pledged_amount"))["total"]
            or Decimal("0.00")
        )
        all_time_calls_count = CallLog.objects.count()

        # Leave & Week-off management
        pending_leaves_count = LeaveRequest.objects.filter(status="PENDING").count()

        # Recent activities
        recent_donations = Donation.objects.all().select_related("agent")[:5]
        recent_pending_leaves = LeaveRequest.objects.filter(status="PENDING").select_related("agent")[:5]
        recent_calls = CallLog.objects.all().select_related("agent")[:10]

        return Response(
            {
                "metrics": {
                    "agents": {
                        "total_agents": total_agents,
                        "active_agents": active_agents,
                        "present_today": present_today,
                        "online_now": online_agents_count,
                    },
                    "donations": {
                        "today_cash_collected": today_cash,
                        "today_cash_count": today_cash_count,
                        "today_product_count": today_product_count,
                        "today_product_total_quantity": today_product_quantity,
                        "all_time_cash_collected": all_time_cash,
                        "all_time_donations_count": all_time_donations_count,
                    },
                    "leaves": {
                        "pending_requests_count": pending_leaves_count,
                    },
                    "telemarketing": {
                        "today_calls_count": today_calls_count,
                        "today_calls_connected": today_calls_connected,
                        "today_calls_pledged": float(today_calls_pledged),
                        "all_time_calls_count": all_time_calls_count,
                    },
                },
                "recent_donations": DonationDetailSerializer(recent_donations, many=True).data,
                "recent_pending_leaves": LeaveRequestDetailSerializer(
                    recent_pending_leaves, many=True
                ).data,
                "recent_calls": CallLogSerializer(recent_calls, many=True).data,
            },
            status=status.HTTP_200_OK,
        )


class AgentDashboardView(APIView):
    """
    Consolidated metrics and status for the Agent Dashboard.
    Matches workflow node: 'Agent Dashboard'
    """

    permission_classes = [IsAgentUserRole]

    @extend_schema(
        responses={200: serializers.DictField()},
        description="Returns today's attendance status, today's targets & progress, recent donations, and latest leave status for Agent Dashboard.",
    )
    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        agent = request.user

        # 1. Attendance status
        attendance = Attendance.objects.filter(agent=agent, date=today).first()
        attendance_data = {
            "date": today,
            "checked_in": bool(attendance and attendance.check_in_time),
            "check_in_time": attendance.check_in_time if attendance else None,
            "checked_out": bool(attendance and attendance.check_out_time),
            "check_out_time": attendance.check_out_time if attendance else None,
            "status": attendance.status if attendance else "NOT_CHECKED_IN",
        }

        # 2. Today's target & progress
        target = DailyTarget.objects.filter(agent=agent, date=today).first()
        if not target:
            target = DailyTarget(
                agent=agent,
                date=today,
                target_cash_amount=Decimal("0.00"),
                target_donations_count=0,
                target_product_units=Decimal("0.00"),
                notes="No target assigned for today.",
            )
        target_data = AgentDailyTargetProgressSerializer(target).data

        # 3. Today's donations summary
        today_cash = (
            Donation.objects.filter(
                agent=agent, donation_type="CASH", created_at__date=today
            ).aggregate(total=Sum("amount"))["total"]
            or Decimal("0.00")
        )
        today_cash_count = Donation.objects.filter(
            agent=agent, donation_type="CASH", created_at__date=today
        ).count()
        today_product_count = Donation.objects.filter(
            agent=agent, donation_type="PRODUCT", created_at__date=today
        ).count()

        # 4. Recent donations
        recent_donations = Donation.objects.filter(agent=agent)[:5]

        # 5. Latest leave request status
        latest_leave = LeaveRequest.objects.filter(agent=agent).first()
        latest_leave_data = (
            LeaveRequestDetailSerializer(latest_leave).data if latest_leave else None
        )

        # 6. Today's telemarketing summary
        agent_today_calls = CallLog.objects.filter(agent=agent, created_at__date=today).count()
        agent_today_pledged = (
            CallLog.objects.filter(agent=agent, created_at__date=today).aggregate(total=Sum("pledged_amount"))["total"]
            or Decimal("0.00")
        )

        return Response(
            {
                "agent_profile": {
                    "id": agent.id,
                    "username": agent.username,
                    "full_name": agent.get_full_name() or agent.username,
                    "employee_id": agent.employee_id,
                    "phone_number": agent.phone_number,
                    "assigned_area": agent.assigned_area,
                },
                "attendance": attendance_data,
                "target": target_data,
                "today_summary": {
                    "cash_amount": today_cash,
                    "cash_entries_count": today_cash_count,
                    "product_entries_count": today_product_count,
                    "total_entries": today_cash_count + today_product_count,
                },
                "telemarketing": {
                    "today_calls_count": agent_today_calls,
                    "today_pledged_amount": float(agent_today_pledged),
                },
                "recent_donations": DonationDetailSerializer(recent_donations, many=True).data,
                "latest_leave_request": latest_leave_data,
            },
            status=status.HTTP_200_OK,
        )
