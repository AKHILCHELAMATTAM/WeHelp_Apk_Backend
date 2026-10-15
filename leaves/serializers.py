from django.utils import timezone
from rest_framework import serializers

from .models import LeaveRequest


class LeaveRequestCreateSerializer(serializers.ModelSerializer):
    """
    Agent workflow:
    'Leave or Week-Off Request' -> 'Submit Request to Admin'
    """

    class Meta:
        model = LeaveRequest
        fields = [
            "id",
            "request_type",
            "start_date",
            "end_date",
            "reason",
            "total_days",
            "status",
            "created_at",
        ]
        read_only_fields = ["id", "total_days", "status", "created_at"]

    def validate(self, attrs):
        start = attrs.get("start_date")
        end = attrs.get("end_date")

        if start and end:
            if start > end:
                raise serializers.ValidationError(
                    {"end_date": "End date must be greater than or equal to start date."}
                )
            # Calculate total calendar days inclusive
            attrs["total_days"] = (end - start).days + 1

        return attrs

    def create(self, validated_data):
        agent = self.context["request"].user
        return LeaveRequest.objects.create(agent=agent, **validated_data)


class LeaveRequestDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer to view Leave/Week-Off requests and approval status.
    Agent: 'Approval or Rejection Status'
    Admin: 'View Agent Requests'
    """

    agent_id = serializers.IntegerField(source="agent.id", read_only=True)
    agent_name = serializers.CharField(source="agent.get_full_name", read_only=True)
    agent_username = serializers.CharField(source="agent.username", read_only=True)
    reviewed_by_name = serializers.CharField(
        source="reviewed_by.get_full_name", read_only=True
    )

    class Meta:
        model = LeaveRequest
        fields = [
            "id",
            "agent_id",
            "agent_username",
            "agent_name",
            "request_type",
            "start_date",
            "end_date",
            "total_days",
            "reason",
            "status",
            "admin_remarks",
            "reviewed_by_name",
            "reviewed_at",
            "created_at",
            "updated_at",
        ]


class LeaveRequestReviewSerializer(serializers.Serializer):
    """
    Admin workflow:
    'Approve Request?' -> 'Approve Leave or Week-Off' / 'Reject Request'
    """

    ACTION_CHOICES = (
        ("APPROVE", "Approve Leave or Week-Off"),
        ("REJECT", "Reject Request"),
    )

    action = serializers.ChoiceField(
        choices=ACTION_CHOICES,
        required=True,
        help_text="Decision: APPROVE or REJECT",
    )
    admin_remarks = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Optional remarks or feedback explaining approval or rejection",
    )
