from decimal import Decimal
from django.utils import timezone
from django.utils.dateparse import parse_date
from drf_spectacular.utils import extend_schema, OpenApiParameter
from rest_framework import generics, serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminUserRole, IsAgentUserRole
from .models import Attendance, DailyTarget
from .serializers import (
    AgentDailyTargetProgressSerializer,
    AttendanceSerializer,
    CheckInSerializer,
    CheckOutSerializer,
    DailyTargetSerializer,
)


class AgentCheckInView(APIView):
    """
    Agent workflow:
    'Attendance' -> Check In with location.
    """

    permission_classes = [IsAgentUserRole]
    serializer_class = CheckInSerializer

    @extend_schema(
        request=CheckInSerializer,
        responses={200: AttendanceSerializer},
        description="Records check-in timestamp and coordinates for today.",
    )
    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)

        today = timezone.localdate()
        now = timezone.now()

        lat = serializer.validated_data.get("latitude")
        lng = serializer.validated_data.get("longitude")
        accuracy = serializer.validated_data.get("accuracy")
        address = serializer.validated_data.get("address")
        notes = serializer.validated_data.get("notes")

        attendance, created = Attendance.objects.get_or_create(
            agent=request.user,
            date=today,
            defaults={
                "check_in_time": now,
                "check_in_latitude": lat,
                "check_in_longitude": lng,
                "check_in_accuracy": accuracy,
                "check_in_address": address,
                "notes": notes,
                "status": "PRESENT",
            },
        )

        if not created:
            if not attendance.check_in_time:
                attendance.check_in_time = now
                attendance.check_in_latitude = lat
                attendance.check_in_longitude = lng
                attendance.check_in_accuracy = accuracy
                attendance.check_in_address = address
                attendance.status = "PRESENT"
                if notes:
                    attendance.notes = f"{attendance.notes or ''}\n{notes}".strip()
                attendance.save()

        # Sync exact check-in location with live agent tracking
        if lat is not None and lng is not None:
            from tracking.models import AgentLocation

            AgentLocation.objects.create(
                agent=request.user,
                latitude=lat,
                longitude=lng,
                accuracy=accuracy,
                address=address or "Checked in for attendance",
                recorded_at=now,
            )

        return Response(
            {
                "message": "Checked in successfully.",
                "attendance": AttendanceSerializer(attendance).data,
            },
            status=status.HTTP_200_OK,
        )


class AgentCheckOutView(APIView):
    """
    Agent workflow:
    'Attendance' -> Check Out with location.
    """

    permission_classes = [IsAgentUserRole]
    serializer_class = CheckOutSerializer

    @extend_schema(
        request=CheckOutSerializer,
        responses={200: AttendanceSerializer},
        description="Records check-out timestamp and coordinates for today.",
    )
    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)

        today = timezone.localdate()
        now = timezone.now()

        try:
            attendance = Attendance.objects.get(agent=request.user, date=today)
        except Attendance.DoesNotExist:
            return Response(
                {"detail": "No check-in record found for today. Please check in first."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        lat = serializer.validated_data.get("latitude")
        lng = serializer.validated_data.get("longitude")
        accuracy = serializer.validated_data.get("accuracy")
        address = serializer.validated_data.get("address")
        notes = serializer.validated_data.get("notes")

        attendance.check_out_time = now
        attendance.check_out_latitude = lat
        attendance.check_out_longitude = lng
        attendance.check_out_accuracy = accuracy
        attendance.check_out_address = address
        if notes:
            attendance.notes = (
                f"{attendance.notes or ''}\nCheck-out note: {notes}".strip()
            )
        attendance.save()

        # Sync exact check-out location with live agent tracking
        if lat is not None and lng is not None:
            from tracking.models import AgentLocation

            AgentLocation.objects.create(
                agent=request.user,
                latitude=lat,
                longitude=lng,
                accuracy=accuracy,
                address=address or "Checked out from attendance",
                recorded_at=now,
            )

        return Response(
            {
                "message": "Checked out successfully.",
                "attendance": AttendanceSerializer(attendance).data,
            },
            status=status.HTTP_200_OK,
        )


class AgentTodayAttendanceStatusView(APIView):
    """
    Returns today's attendance status for the authenticated agent.
    """

    permission_classes = [IsAgentUserRole]

    @extend_schema(
        responses={200: serializers.DictField()},
        description="Returns today's attendance status for the authenticated agent.",
    )
    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        attendance = Attendance.objects.filter(agent=request.user, date=today).first()

        if not attendance:
            return Response(
                {
                    "date": today,
                    "checked_in": False,
                    "checked_out": False,
                    "status": "NOT_CHECKED_IN",
                    "attendance": None,
                }
            )

        return Response(
            {
                "date": today,
                "checked_in": bool(attendance.check_in_time),
                "checked_out": bool(attendance.check_out_time),
                "status": attendance.status,
                "attendance": AttendanceSerializer(attendance).data,
            }
        )


class AgentAttendanceHistoryView(generics.ListAPIView):
    """
    Returns historical attendance records for the authenticated agent.
    """

    permission_classes = [IsAgentUserRole]
    serializer_class = AttendanceSerializer

    def get_queryset(self):
        return Attendance.objects.filter(agent=self.request.user)


class AgentTodayTargetView(APIView):
    """
    Agent workflow:
    'Attendance' -> 'Display Today's Target' -> 'View Daily Target'
    Returns today's daily target along with real-time achieved metrics.
    """

    permission_classes = [IsAgentUserRole]

    @extend_schema(
        responses={200: AgentDailyTargetProgressSerializer},
        description="Returns today's daily target assigned to agent and achieved collection metrics.",
    )
    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        agent = request.user

        target = DailyTarget.objects.filter(agent=agent, date=today).first()
        if not target:
            # Create a virtual/default target so agent can still see their day's progress
            target = DailyTarget(
                agent=agent,
                date=today,
                target_cash_amount=Decimal("0.00"),
                target_donations_count=0,
                target_product_units=Decimal("0.00"),
                notes="No target assigned by administrator for today.",
            )

        serializer = AgentDailyTargetProgressSerializer(target)
        return Response(serializer.data, status=status.HTTP_200_OK)


# --- ADMIN VIEWS ---


class AdminAttendanceListView(generics.ListAPIView):
    """
    Admin endpoint to view and filter attendance records across all agents.
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = AttendanceSerializer

    def get_queryset(self):
        queryset = Attendance.objects.all().select_related("agent")
        agent_id = self.request.query_params.get("agent_id")
        date_str = self.request.query_params.get("date")
        status_filter = self.request.query_params.get("status")

        if agent_id:
            queryset = queryset.filter(agent_id=agent_id)
        if date_str:
            target_date = parse_date(date_str)
            if target_date:
                queryset = queryset.filter(date=target_date)
        if status_filter:
            queryset = queryset.filter(status=status_filter.upper())

        return queryset

    @extend_schema(
        parameters=[
            OpenApiParameter(name="agent_id", type=int, description="Filter by Agent ID"),
            OpenApiParameter(name="date", type=str, description="Filter by date (YYYY-MM-DD)"),
            OpenApiParameter(name="status", type=str, description="Filter by PRESENT, HALF_DAY, ABSENT"),
        ]
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class AdminDailyTargetListCreateView(generics.ListCreateAPIView):
    """
    Admin endpoint to set or list daily targets for agents.
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = DailyTargetSerializer

    def get_queryset(self):
        queryset = DailyTarget.objects.all().select_related("agent", "assigned_by")
        agent_id = self.request.query_params.get("agent_id")
        date_str = self.request.query_params.get("date")

        if agent_id:
            queryset = queryset.filter(agent_id=agent_id)
        if date_str:
            target_date = parse_date(date_str)
            if target_date:
                queryset = queryset.filter(date=target_date)

        return queryset

    def perform_create(self, serializer):
        serializer.save(assigned_by=self.request.user)


class AdminDailyTargetDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Admin endpoint to view, edit, or delete a daily target.
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = DailyTargetSerializer
    queryset = DailyTarget.objects.all()
