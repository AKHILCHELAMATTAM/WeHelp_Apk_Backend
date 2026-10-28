from decimal import Decimal
from rest_framework import serializers
from .models import CallLog, TelemarketingLead


class CallLogSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for telemarketing call logs.
    """

    agent_id = serializers.IntegerField(source="agent.id", read_only=True)
    agent_username = serializers.CharField(source="agent.username", read_only=True)
    agent_name = serializers.SerializerMethodField()
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    call_type_display = serializers.CharField(source="get_call_type_display", read_only=True)
    formatted_duration = serializers.CharField(read_only=True)

    class Meta:
        model = CallLog
        fields = [
            "id",
            "agent_id",
            "agent_username",
            "agent_name",
            "contact_name",
            "phone_number",
            "call_type",
            "call_type_display",
            "status",
            "status_display",
            "call_duration_seconds",
            "formatted_duration",
            "pledged_amount",
            "notes",
            "follow_up_date",
            "lead_category",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def get_agent_name(self, obj):
        full = obj.agent.get_full_name()
        return full if full else obj.agent.username


class CallLogCreateSerializer(serializers.ModelSerializer):
    """
    Serializer used by agents in the mobile app to record a call outcome.
    """

    class Meta:
        model = CallLog
        fields = [
            "contact_name",
            "phone_number",
            "call_type",
            "status",
            "call_duration_seconds",
            "pledged_amount",
            "notes",
            "follow_up_date",
            "lead_category",
        ]

    def validate_phone_number(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("Phone number cannot be empty.")
        return cleaned

    def validate_pledged_amount(self, value):
        if value is not None and value < Decimal("0.00"):
            raise serializers.ValidationError("Pledged amount cannot be negative.")
        return value

    def create(self, validated_data):
        # Auto-set the authenticated agent
        user = self.context["request"].user
        validated_data["agent"] = user
        call_log = super().create(validated_data)

        # Update matching lead if one exists with the phone number
        cleaned_phone = validated_data["phone_number"].replace(" ", "").replace("-", "")
        lead = TelemarketingLead.objects.filter(
            phone_number__icontains=cleaned_phone[-10:]
        ).first()
        if lead:
            lead.total_calls_count += 1
            lead.last_called_at = call_log.created_at
            if call_log.status == "DONATION_PLEDGED":
                lead.status = "CONVERTED"
            elif call_log.status == "CALLBACK_REQUESTED":
                lead.status = "CALLBACK"
            elif call_log.status in ["CONNECTED", "INTERESTED"]:
                lead.status = "IN_PROGRESS"
            lead.save()

        return call_log


class TelemarketingLeadSerializer(serializers.ModelSerializer):
    """
    Serializer for telemarketing contacts and leads list.
    """

    status_display = serializers.CharField(source="get_status_display", read_only=True)
    category_display = serializers.CharField(source="get_category_display", read_only=True)
    assigned_agent_name = serializers.SerializerMethodField()

    class Meta:
        model = TelemarketingLead
        fields = [
            "id",
            "name",
            "phone_number",
            "email",
            "city",
            "category",
            "category_display",
            "status",
            "status_display",
            "assigned_agent",
            "assigned_agent_name",
            "total_calls_count",
            "last_called_at",
            "notes",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def get_assigned_agent_name(self, obj):
        if obj.assigned_agent:
            full = obj.assigned_agent.get_full_name()
            return full if full else obj.assigned_agent.username
        return "Unassigned (All Agents)"
