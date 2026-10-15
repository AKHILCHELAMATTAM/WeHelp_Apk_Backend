from datetime import timedelta
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.utils.dateparse import parse_date
from drf_spectacular.utils import extend_schema, OpenApiParameter
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminUserRole, IsAgentUserRole
from .models import AgentLocation
from .serializers import (
    AgentLocationSendSerializer,
    AgentLocationSerializer,
    LiveAgentTrackingSerializer,
)

User = get_user_model()


class AgentSendLocationView(APIView):
    """
    Agent workflow:
    'Access Location' -> 'Request GPS Permission if Needed' -> 'Capture Agent Location' -> 'Send Location to Backend'
    """

    permission_classes = [IsAgentUserRole]
    serializer_class = AgentLocationSendSerializer

    @extend_schema(
        request=AgentLocationSendSerializer,
        responses={201: AgentLocationSerializer},
        description="Receives real-time GPS coordinates captured by the agent Android device.",
    )
    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        location = serializer.save()

        return Response(
            {
                "message": "GPS location successfully recorded.",
                "data": AgentLocationSerializer(location).data,
            },
            status=status.HTTP_201_CREATED,
        )


class AgentLatestLocationView(APIView):
    """
    Returns the last recorded GPS location of the authenticated agent.
    """

    permission_classes = [IsAgentUserRole]

    @extend_schema(
        responses={200: AgentLocationSerializer},
        description="Returns latest recorded GPS location of the authenticated agent.",
    )
    def get(self, request, *args, **kwargs):
        location = (
            AgentLocation.objects.filter(agent=request.user)
            .order_by("-recorded_at")
            .first()
        )
        if not location:
            return Response(
                {"detail": "No location records found for this agent."},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(AgentLocationSerializer(location).data)


class AdminLiveTrackingView(APIView):
    """
    Admin workflow:
    'Agent Location Tracking' -> 'View Agent Location on Map' -> 'View Latitude Longitude and Location'
    Returns current live coordinates for all active agents.
    """

    permission_classes = [IsAdminUserRole]

    @extend_schema(
        responses={200: LiveAgentTrackingSerializer(many=True)},
        description="Returns latest GPS coordinates and status for all active field agents.",
    )
    def get(self, request, *args, **kwargs):
        agents = User.objects.filter(role="AGENT", is_active_agent=True)
        now = timezone.now()
        fifteen_mins_ago = now - timedelta(minutes=15)

        live_data = []
        for agent in agents:
            latest_loc = (
                AgentLocation.objects.filter(agent=agent)
                .order_by("-recorded_at")
                .first()
            )

            is_online = bool(latest_loc and latest_loc.recorded_at >= fifteen_mins_ago)

            live_data.append(
                {
                    "agent_id": agent.id,
                    "agent_username": agent.username,
                    "agent_name": agent.get_full_name() or agent.username,
                    "phone_number": agent.phone_number,
                    "employee_id": agent.employee_id,
                    "assigned_area": agent.assigned_area,
                    "latitude": latest_loc.latitude if latest_loc else None,
                    "longitude": latest_loc.longitude if latest_loc else None,
                    "accuracy": latest_loc.accuracy if latest_loc else None,
                    "battery_level": latest_loc.battery_level if latest_loc else None,
                    "address": latest_loc.address if latest_loc else None,
                    "last_updated": latest_loc.recorded_at if latest_loc else None,
                    "is_online": is_online,
                }
            )

        serializer = LiveAgentTrackingSerializer(live_data, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)


class AdminAgentLocationHistoryView(generics.ListAPIView):
    """
    Admin endpoint to view historical breadcrumb path of an agent.
    Supports filtering by specific date (YYYY-MM-DD).
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = AgentLocationSerializer

    def get_queryset(self):
        agent_id = self.kwargs.get("agent_id")
        queryset = AgentLocation.objects.filter(agent_id=agent_id).order_by("-recorded_at")

        date_str = self.request.query_params.get("date")
        if date_str:
            target_date = parse_date(date_str)
            if target_date:
                queryset = queryset.filter(recorded_at__date=target_date)

        return queryset

    @extend_schema(
        parameters=[
            OpenApiParameter(
                name="date",
                type=str,
                description="Filter history by date (YYYY-MM-DD)",
            )
        ]
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
