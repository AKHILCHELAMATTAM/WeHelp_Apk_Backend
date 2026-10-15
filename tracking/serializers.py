from datetime import timedelta
from django.utils import timezone
from rest_framework import serializers

from .models import AgentLocation


class AgentLocationSendSerializer(serializers.ModelSerializer):
    """
    Used by Agent on Android App:
    'Send Location to Backend'
    """

    class Meta:
        model = AgentLocation
        fields = [
            "latitude",
            "longitude",
            "accuracy",
            "speed",
            "altitude",
            "battery_level",
            "address",
            "recorded_at",
        ]

    def validate_latitude(self, value):
        if not (-90.0 <= value <= 90.0):
            raise serializers.ValidationError("Latitude must be between -90 and +90 degrees.")
        return value

    def validate_longitude(self, value):
        if not (-180.0 <= value <= 180.0):
            raise serializers.ValidationError("Longitude must be between -180 and +180 degrees.")
        return value

    def create(self, validated_data):
        agent = self.context["request"].user
        return AgentLocation.objects.create(agent=agent, **validated_data)


class AgentLocationSerializer(serializers.ModelSerializer):
    """
    Detailed location serializer for viewing coordinates history.
    """

    agent_id = serializers.IntegerField(source="agent.id", read_only=True)
    agent_name = serializers.CharField(source="agent.get_full_name", read_only=True)
    agent_username = serializers.CharField(source="agent.username", read_only=True)

    class Meta:
        model = AgentLocation
        fields = [
            "id",
            "agent_id",
            "agent_username",
            "agent_name",
            "latitude",
            "longitude",
            "accuracy",
            "speed",
            "altitude",
            "battery_level",
            "address",
            "recorded_at",
            "created_at",
        ]


class LiveAgentTrackingSerializer(serializers.Serializer):
    """
    Used by Admin:
    'Agent Location Tracking' -> 'View Agent Location on Map' -> 'View Latitude Longitude and Location'
    """

    agent_id = serializers.IntegerField()
    agent_username = serializers.CharField()
    agent_name = serializers.CharField()
    phone_number = serializers.CharField(allow_null=True)
    employee_id = serializers.CharField(allow_null=True)
    assigned_area = serializers.CharField(allow_null=True)
    latitude = serializers.FloatField(allow_null=True)
    longitude = serializers.FloatField(allow_null=True)
    accuracy = serializers.FloatField(allow_null=True)
    battery_level = serializers.IntegerField(allow_null=True)
    address = serializers.CharField(allow_null=True)
    last_updated = serializers.DateTimeField(allow_null=True)
    is_online = serializers.BooleanField()
