from django.db import models
from drf_spectacular.utils import extend_schema, OpenApiParameter
from rest_framework import generics, serializers, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import User
from .permissions import IsAdminUserRole
from .serializers import (
    AgentCreateSerializer,
    AgentDetailSerializer,
    RoleBasedLoginSerializer,
    UserProfileSerializer,
)


class RoleBasedLoginView(APIView):
    """
    Role-based authentication endpoint for the Android App.
    Accepts credentials and requested role (ADMIN or AGENT).
    """

    permission_classes = [AllowAny]
    serializer_class = RoleBasedLoginSerializer

    @extend_schema(
        request=RoleBasedLoginSerializer,
        responses={200: UserProfileSerializer},
        description="Authenticates Admin or Agent according to role chosen in Android App.",
    )
    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data["user"]
        tokens = serializer.validated_data["tokens"]

        user_data = UserProfileSerializer(user).data

        return Response(
            {
                "message": f"Welcome {user.get_full_name() or user.username}! Login successful.",
                "role": user.role,
                "tokens": tokens,
                "user": user_data,
            },
            status=status.HTTP_200_OK,
        )


class UserProfileView(generics.RetrieveUpdateAPIView):
    """
    Retrieves or updates the profile of the currently logged-in user.
    """

    permission_classes = [IsAuthenticated]
    serializer_class = UserProfileSerializer

    def get_object(self):
        return self.request.user


class AdminAgentListCreateView(generics.ListCreateAPIView):
    """
    Admin workflow:
    'Agent Creation' -> 'Create Agent Username and Password' -> 'Save Agent Account'
    Also lists all agents with search & filtering.
    """

    permission_classes = [IsAdminUserRole]

    def get_serializer_class(self):
        if self.request.method == "POST":
            return AgentCreateSerializer
        return AgentDetailSerializer

    def get_queryset(self):
        queryset = User.objects.filter(role="AGENT").order_by("-created_at")
        search = self.request.query_params.get("search")
        is_active = self.request.query_params.get("is_active")

        if search:
            queryset = queryset.filter(
                models.Q(username__icontains=search)
                | models.Q(first_name__icontains=search)
                | models.Q(last_name__icontains=search)
                | models.Q(employee_id__icontains=search)
                | models.Q(assigned_area__icontains=search)
            )
        if is_active is not None:
            active_bool = is_active.lower() in ["true", "1"]
            queryset = queryset.filter(is_active_agent=active_bool)

        return queryset

    @extend_schema(
        parameters=[
            OpenApiParameter(
                name="search",
                type=str,
                description="Search by name, username, employee ID, or assigned area",
            ),
            OpenApiParameter(
                name="is_active",
                type=bool,
                description="Filter by active status (true/false)",
            ),
        ]
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        agent = serializer.save()
        response_serializer = AgentDetailSerializer(agent)
        return Response(
            {
                "message": "Agent account created successfully.",
                "agent": response_serializer.data,
            },
            status=status.HTTP_201_CREATED,
        )


class AdminAgentDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Admin endpoint to retrieve, update, or remove an agent account.
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = AgentDetailSerializer
    queryset = User.objects.filter(role="AGENT")


class AdminAgentStatusToggleView(APIView):
    """
    Admin endpoint to activate or deactivate an agent account.
    """

    permission_classes = [IsAdminUserRole]

    @extend_schema(
        request=None,
        responses={200: serializers.DictField()},
        description="Admin endpoint to toggle an agent account between active and deactivated status.",
    )
    def post(self, request, pk, *args, **kwargs):
        try:
            agent = User.objects.get(pk=pk, role="AGENT")
        except User.DoesNotExist:
            return Response(
                {"detail": "Agent not found."}, status=status.HTTP_404_NOT_FOUND
            )

        agent.is_active_agent = not agent.is_active_agent
        agent.save(update_fields=["is_active_agent", "updated_at"])
        status_text = "activated" if agent.is_active_agent else "deactivated"
        return Response(
            {
                "message": f"Agent account has been {status_text}.",
                "agent_id": agent.id,
                "is_active_agent": agent.is_active_agent,
            },
            status=status.HTTP_200_OK,
        )
