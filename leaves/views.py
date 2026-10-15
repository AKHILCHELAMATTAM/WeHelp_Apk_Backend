from django.utils import timezone
from drf_spectacular.utils import extend_schema, OpenApiParameter
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminUserRole, IsAgentUserRole
from .models import LeaveRequest
from .serializers import (
    LeaveRequestCreateSerializer,
    LeaveRequestDetailSerializer,
    LeaveRequestReviewSerializer,
)


class AgentLeaveListCreateView(generics.ListCreateAPIView):
    """
    Agent workflow:
    'Leave or Week-Off Request' -> 'Submit Request to Admin'
    'Approval or Rejection Status' (view list of own requests)
    """

    permission_classes = [IsAgentUserRole]

    def get_serializer_class(self):
        if self.request.method == "POST":
            return LeaveRequestCreateSerializer
        return LeaveRequestDetailSerializer

    def get_queryset(self):
        queryset = LeaveRequest.objects.filter(agent=self.request.user)
        req_type = self.request.query_params.get("request_type")
        status_filter = self.request.query_params.get("status")

        if req_type:
            queryset = queryset.filter(request_type=req_type.upper())
        if status_filter:
            queryset = queryset.filter(status=status_filter.upper())

        return queryset

    @extend_schema(
        parameters=[
            OpenApiParameter(name="request_type", type=str, description="LEAVE or WEEK_OFF"),
            OpenApiParameter(name="status", type=str, description="PENDING, APPROVED, REJECTED"),
        ]
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        leave = serializer.save()
        return Response(
            {
                "message": f"{leave.get_request_type_display()} request submitted to administrator successfully.",
                "request": LeaveRequestDetailSerializer(leave).data,
            },
            status=status.HTTP_201_CREATED,
        )


class AgentLeaveDetailView(generics.RetrieveAPIView):
    """
    Agent endpoint: view details of a specific submitted request.
    """

    permission_classes = [IsAgentUserRole]
    serializer_class = LeaveRequestDetailSerializer

    def get_queryset(self):
        return LeaveRequest.objects.filter(agent=self.request.user)


# --- ADMIN VIEWS ---


class AdminLeaveListView(generics.ListAPIView):
    """
    Admin workflow:
    'Leave and Week-Off Management' -> 'View Agent Requests'
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = LeaveRequestDetailSerializer

    def get_queryset(self):
        queryset = LeaveRequest.objects.all().select_related("agent", "reviewed_by")
        agent_id = self.request.query_params.get("agent_id")
        req_type = self.request.query_params.get("request_type")
        status_filter = self.request.query_params.get("status")

        if agent_id:
            queryset = queryset.filter(agent_id=agent_id)
        if req_type:
            queryset = queryset.filter(request_type=req_type.upper())
        if status_filter:
            queryset = queryset.filter(status=status_filter.upper())

        return queryset

    @extend_schema(
        parameters=[
            OpenApiParameter(name="agent_id", type=int, description="Filter by Agent ID"),
            OpenApiParameter(name="request_type", type=str, description="LEAVE or WEEK_OFF"),
            OpenApiParameter(name="status", type=str, description="PENDING, APPROVED, REJECTED"),
        ]
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class AdminLeaveDetailView(generics.RetrieveAPIView):
    """
    Admin endpoint to view a specific request in detail.
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = LeaveRequestDetailSerializer
    queryset = LeaveRequest.objects.all()


class AdminLeaveReviewView(APIView):
    """
    Admin workflow:
    'Approve Request?' -> 'Approve Leave or Week-Off' / 'Reject Request'
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = LeaveRequestReviewSerializer

    @extend_schema(
        request=LeaveRequestReviewSerializer,
        responses={200: LeaveRequestDetailSerializer},
        description="Approves or Rejects a pending agent leave/week-off request.",
    )
    def post(self, request, pk, *args, **kwargs):
        try:
            leave = LeaveRequest.objects.get(pk=pk)
        except LeaveRequest.DoesNotExist:
            return Response(
                {"detail": "Leave request not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)

        action = serializer.validated_data["action"]
        admin_remarks = serializer.validated_data.get("admin_remarks", "")

        if action == "APPROVE":
            leave.status = "APPROVED"
            action_verb = "approved"
        else:
            leave.status = "REJECTED"
            action_verb = "rejected"

        leave.admin_remarks = admin_remarks
        leave.reviewed_by = request.user
        leave.reviewed_at = timezone.now()
        leave.save(
            update_fields=["status", "admin_remarks", "reviewed_by", "reviewed_at", "updated_at"]
        )

        return Response(
            {
                "message": f"Leave request has been {action_verb}.",
                "request": LeaveRequestDetailSerializer(leave).data,
            },
            status=status.HTTP_200_OK,
        )
