from decimal import Decimal
from django.db.models import Count, Q, Sum
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminUserRole, IsAgentUserRole
from .models import CallLog, TelemarketingLead
from .serializers import (
    CallLogCreateSerializer,
    CallLogSerializer,
    TelemarketingLeadSerializer,
)


class AgentCallLogListCreateView(APIView):
    """
    Endpoints for field agents and telemarketing staff to:
    - POST: Log a completed call outcome and remarks.
    - GET: Retrieve their personal history of call logs.
    """

    permission_classes = [IsAgentUserRole]

    @extend_schema(
        parameters=[
            OpenApiParameter("search", str, description="Search by contact name or phone number"),
            OpenApiParameter("status", str, description="Filter by status (e.g. CONNECTED, INTERESTED, DONATION_PLEDGED)"),
            OpenApiParameter("date", str, description="Filter by date (YYYY-MM-DD)"),
        ],
        responses={200: CallLogSerializer(many=True)},
        description="Returns list of call logs recorded by the authenticated telemarketing staff.",
    )
    def get(self, request, *args, **kwargs):
        queryset = CallLog.objects.filter(agent=request.user)

        search = request.query_params.get("search", "").strip()
        if search:
            queryset = queryset.filter(
                Q(contact_name__icontains=search) | Q(phone_number__icontains=search)
            )

        call_status = request.query_params.get("status", "").strip()
        if call_status:
            queryset = queryset.filter(status=call_status)

        date_str = request.query_params.get("date", "").strip()
        if date_str:
            queryset = queryset.filter(created_at__date=date_str)

        serializer = CallLogSerializer(queryset[:100], many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @extend_schema(
        request=CallLogCreateSerializer,
        responses={201: CallLogSerializer},
        description="Records a new telemarketing call outcome with notes, disposition, and optional pledge.",
    )
    def post(self, request, *args, **kwargs):
        serializer = CallLogCreateSerializer(data=request.data, context={"request": request})
        if serializer.is_valid():
            call_log = serializer.save()
            return Response(
                {
                    "message": "Call log recorded successfully and sent to admin.",
                    "call_log": CallLogSerializer(call_log).data,
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AgentCallLogDetailView(generics.RetrieveUpdateAPIView):
    """
    Allows the authenticated agent to view or update notes, disposition,
    and donation pledges on their recorded call logs.
    """

    permission_classes = [IsAgentUserRole]
    serializer_class = CallLogSerializer

    def get_queryset(self):
        return CallLog.objects.filter(agent=self.request.user)


class AgentCallSummaryView(APIView):
    """
    Summary metrics for the authenticated agent's telemarketing performance.
    """

    permission_classes = [IsAgentUserRole]

    @extend_schema(
        responses={200: dict},
        description="Returns today's call counts, connected calls, and total pledged donations for the agent.",
    )
    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        agent_calls = CallLog.objects.filter(agent=request.user)
        today_calls = agent_calls.filter(created_at__date=today)

        today_count = today_calls.count()
        today_connected = today_calls.filter(
            status__in=["CONNECTED", "INTERESTED", "DONATION_PLEDGED"]
        ).count()
        today_pledged = (
            today_calls.aggregate(total=Sum("pledged_amount"))["total"] or Decimal("0.00")
        )

        total_count = agent_calls.count()
        total_pledged = (
            agent_calls.aggregate(total=Sum("pledged_amount"))["total"] or Decimal("0.00")
        )

        return Response(
            {
                "today_calls_count": today_count,
                "today_connected_count": today_connected,
                "today_pledged_amount": float(today_pledged),
                "total_calls_count": total_count,
                "total_pledged_amount": float(total_pledged),
            },
            status=status.HTTP_200_OK,
        )


class AgentTelemarketingLeadsView(APIView):
    """
    Retrieves donor and telemarketing contacts available for the agent to call.
    Also allows agents to add new leads directly from the field.
    """

    permission_classes = [IsAgentUserRole]

    @extend_schema(
        parameters=[
            OpenApiParameter("search", str, description="Search lead by name, phone, or city"),
            OpenApiParameter("status", str, description="Filter by status (NEW, IN_PROGRESS, CALLBACK, CONVERTED)"),
        ],
        responses={200: TelemarketingLeadSerializer(many=True)},
        description="Returns list of telemarketing leads to call.",
    )
    def get(self, request, *args, **kwargs):
        queryset = TelemarketingLead.objects.filter(
            Q(assigned_agent=request.user) | Q(assigned_agent__isnull=True)
        ).exclude(status="DO_NOT_CALL")

        search = request.query_params.get("search", "").strip()
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search)
                | Q(phone_number__icontains=search)
                | Q(city__icontains=search)
            )

        lead_status = request.query_params.get("status", "").strip()
        if lead_status:
            queryset = queryset.filter(status=lead_status)

        serializer = TelemarketingLeadSerializer(queryset[:100], many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @extend_schema(
        request=TelemarketingLeadSerializer,
        responses={201: TelemarketingLeadSerializer},
        description="Creates a new telemarketing lead.",
    )
    def post(self, request, *args, **kwargs):
        serializer = TelemarketingLeadSerializer(data=request.data)
        if serializer.is_valid():
            lead = serializer.save(assigned_agent=request.user)
            return Response(
                {"message": "Lead created successfully.", "lead": TelemarketingLeadSerializer(lead).data},
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminCallLogListView(APIView):
    """
    Comprehensive list of all call logs across all telemarketing staff for the Admin Panel.
    Supports filtering by agent, disposition, date range, and search.
    """

    permission_classes = [IsAdminUserRole]

    @extend_schema(
        parameters=[
            OpenApiParameter("agent_id", int, description="Filter by agent user ID"),
            OpenApiParameter("status", str, description="Filter by call outcome disposition"),
            OpenApiParameter("search", str, description="Search contact name, phone, or notes"),
            OpenApiParameter("date_from", str, description="Start date (YYYY-MM-DD)"),
            OpenApiParameter("date_to", str, description="End date (YYYY-MM-DD)"),
        ],
        responses={200: CallLogSerializer(many=True)},
        description="Admin view of all telemarketing call logs across all staff.",
    )
    def get(self, request, *args, **kwargs):
        queryset = CallLog.objects.select_related("agent").all()

        agent_id = request.query_params.get("agent_id")
        if agent_id:
            queryset = queryset.filter(agent_id=agent_id)

        call_status = request.query_params.get("status", "").strip()
        if call_status:
            queryset = queryset.filter(status=call_status)

        search = request.query_params.get("search", "").strip()
        if search:
            queryset = queryset.filter(
                Q(contact_name__icontains=search)
                | Q(phone_number__icontains=search)
                | Q(notes__icontains=search)
                | Q(agent__username__icontains=search)
                | Q(agent__first_name__icontains=search)
            )

        date_from = request.query_params.get("date_from", "").strip()
        if date_from:
            queryset = queryset.filter(created_at__date__gte=date_from)

        date_to = request.query_params.get("date_to", "").strip()
        if date_to:
            queryset = queryset.filter(created_at__date__lte=date_to)

        serializer = CallLogSerializer(queryset[:200], many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class AdminCallLogSummaryView(APIView):
    """
    Consolidated analytics for the admin panel on telemarketing performance.
    """

    permission_classes = [IsAdminUserRole]

    @extend_schema(
        responses={200: dict},
        description="Returns consolidated telemarketing metrics, disposition breakdown, and agent rankings.",
    )
    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        today_calls = CallLog.objects.filter(created_at__date=today)

        total_calls = CallLog.objects.count()
        today_calls_count = today_calls.count()
        today_connected = today_calls.filter(
            status__in=["CONNECTED", "INTERESTED", "DONATION_PLEDGED"]
        ).count()

        total_pledged = (
            CallLog.objects.aggregate(total=Sum("pledged_amount"))["total"] or Decimal("0.00")
        )
        today_pledged = (
            today_calls.aggregate(total=Sum("pledged_amount"))["total"] or Decimal("0.00")
        )

        # Breakdown by disposition
        disposition_counts = dict(
            CallLog.objects.values("status").annotate(count=Count("id")).values_list("status", "count")
        )

        # Agent breakdown today
        agent_performance = (
            today_calls.values("agent__id", "agent__username", "agent__first_name", "agent__last_name")
            .annotate(
                total_calls=Count("id"),
                pledged=Sum("pledged_amount"),
            )
            .order_by("-total_calls")
        )

        return Response(
            {
                "total_calls_all_time": total_calls,
                "today_calls_count": today_calls_count,
                "today_connected_count": today_connected,
                "total_pledged_amount": float(total_pledged),
                "today_pledged_amount": float(today_pledged),
                "disposition_breakdown": disposition_counts,
                "agent_performance_today": list(agent_performance),
            },
            status=status.HTTP_200_OK,
        )


class AdminTelemarketingLeadListCreateView(generics.ListCreateAPIView):
    """
    Admin management of telemarketing leads database.
    """

    permission_classes = [IsAdminUserRole]
    queryset = TelemarketingLead.objects.all()
    serializer_class = TelemarketingLeadSerializer
