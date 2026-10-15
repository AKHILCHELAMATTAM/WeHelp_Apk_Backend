from django.contrib.auth import authenticate
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User


class RoleBasedLoginSerializer(serializers.Serializer):
    """
    Handles authentication based on selected role (Admin or Agent) from the Android App.
    Matches workflow:
    'Select User Role' -> 'Admin' / 'Agent' -> 'Enter Assigned Username and Password' -> 'Credentials Valid?'
    """

    username = serializers.CharField(required=True)
    password = serializers.CharField(
        required=True, write_only=True, style={"input_type": "password"}
    )
    role = serializers.ChoiceField(
        choices=User.ROLE_CHOICES,
        required=True,
        help_text="Role chosen in the mobile app: ADMIN or AGENT",
    )

    def validate(self, attrs):
        username = attrs.get("username")
        password = attrs.get("password")
        role = attrs.get("role")

        user = authenticate(username=username, password=password)

        if not user:
            raise serializers.ValidationError(
                {
                    "detail": "Invalid credentials provided. Please check your username and password."
                }
            )

        if not user.is_active:
            raise serializers.ValidationError(
                {"detail": "This account is inactive. Please contact your administrator."}
            )

        # Check if user role matches the chosen role
        # Admins can log in if they have role ADMIN or superuser status
        if role == "ADMIN":
            if user.role != "ADMIN" and not (user.is_staff or user.is_superuser):
                raise serializers.ValidationError(
                    {"detail": "Access denied. This user does not have Administrator privileges."}
                )
        elif role == "AGENT":
            if user.role != "AGENT":
                raise serializers.ValidationError(
                    {"detail": "Access denied. This user is not registered as an Agent."}
                )
            if not user.is_active_agent:
                raise serializers.ValidationError(
                    {"detail": "This agent account has been deactivated. Please contact your administrator."}
                )

        refresh = RefreshToken.for_user(user)

        # Include custom claims
        refresh["role"] = user.role
        refresh["username"] = user.username

        attrs["user"] = user
        attrs["tokens"] = {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
        }
        return attrs


class UserProfileSerializer(serializers.ModelSerializer):
    """
    Serializes profile information for authenticated user.
    """

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "first_name",
            "last_name",
            "email",
            "role",
            "phone_number",
            "employee_id",
            "assigned_area",
            "is_active_agent",
            "date_joined",
            "last_login",
        ]
        read_only_fields = [
            "id",
            "username",
            "role",
            "employee_id",
            "is_active_agent",
            "date_joined",
            "last_login",
        ]


class AgentCreateSerializer(serializers.ModelSerializer):
    """
    Admin workflow:
    'Agent Creation' -> 'Create Agent Username and Password' -> 'Save Agent Account'
    """

    password = serializers.CharField(
        write_only=True,
        required=True,
        min_length=6,
        style={"input_type": "password"},
        help_text="Password to assign to the new agent",
    )

    is_active_agent = serializers.BooleanField(
        default=True, required=False, help_text="Active status for field duty"
    )

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "password",
            "first_name",
            "last_name",
            "email",
            "phone_number",
            "employee_id",
            "assigned_area",
            "is_active_agent",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate_username(self, value):
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("An account with this username already exists.")
        return value

    def create(self, validated_data):
        password = validated_data.pop("password")
        request = self.context.get("request")
        created_by = request.user if request and request.user.is_authenticated else None
        is_active_agent = validated_data.pop("is_active_agent", True)

        agent = User(
            **validated_data,
            role="AGENT",
            created_by=created_by,
            is_active_agent=is_active_agent,
        )
        agent.set_password(password)
        agent.save()
        return agent


class AgentDetailSerializer(serializers.ModelSerializer):
    """
    Admin management view for agent profiles.
    """

    created_by_name = serializers.CharField(
        source="created_by.get_full_name", read_only=True
    )

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "first_name",
            "last_name",
            "email",
            "role",
            "phone_number",
            "employee_id",
            "assigned_area",
            "is_active_agent",
            "is_active",
            "created_by",
            "created_by_name",
            "created_at",
            "updated_at",
            "last_login",
        ]
        read_only_fields = [
            "id",
            "role",
            "created_by",
            "created_by_name",
            "created_at",
            "updated_at",
            "last_login",
        ]
