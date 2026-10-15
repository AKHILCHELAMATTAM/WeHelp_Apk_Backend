from decimal import Decimal
from django.db.models import Sum
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from donations.models import Donation
from .models import Attendance, DailyTarget


class CheckInSerializer(serializers.Serializer):
    latitude = serializers.FloatField(
        required=True,
        min_value=-90.0,
        max_value=90.0,
        help_text="Exact GPS latitude of the agent at check-in (e.g. 28.5355)",
    )
    longitude = serializers.FloatField(
        required=True,
        min_value=-180.0,
        max_value=180.0,
        help_text="Exact GPS longitude of the agent at check-in (e.g. 77.3910)",
    )
    accuracy = serializers.FloatField(
        required=False,
        allow_null=True,
        help_text="GPS accuracy radius in meters (e.g. 5.2)",
    )
    address = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=255,
        help_text="Human-readable location or landmark",
    )
    notes = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Optional morning notes or remarks",
    )


class CheckOutSerializer(serializers.Serializer):
    latitude = serializers.FloatField(
        required=True,
        min_value=-90.0,
        max_value=90.0,
        help_text="Exact GPS latitude of the agent at check-out (e.g. 28.5358)",
    )
    longitude = serializers.FloatField(
        required=True,
        min_value=-180.0,
        max_value=180.0,
        help_text="Exact GPS longitude of the agent at check-out (e.g. 77.3915)",
    )
    accuracy = serializers.FloatField(
        required=False,
        allow_null=True,
        help_text="GPS accuracy radius in meters (e.g. 4.8)",
    )
    address = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=255,
        help_text="Human-readable location or landmark",
    )
    notes = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Optional end-of-day notes or summary",
    )


class AttendanceSerializer(serializers.ModelSerializer):
    agent_name = serializers.CharField(source="agent.get_full_name", read_only=True)
    agent_username = serializers.CharField(source="agent.username", read_only=True)
    check_in_google_map_link = serializers.CharField(read_only=True)
    check_in_map_url = serializers.CharField(read_only=True)
    check_out_google_map_link = serializers.CharField(read_only=True)
    check_out_map_url = serializers.CharField(read_only=True)

    class Meta:
        model = Attendance
        fields = [
            "id",
            "agent_id",
            "agent_username",
            "agent_name",
            "date",
            "check_in_time",
            "check_out_time",
            "check_in_latitude",
            "check_in_longitude",
            "check_in_accuracy",
            "check_in_address",
            "check_in_google_map_link",
            "check_in_map_url",
            "check_out_latitude",
            "check_out_longitude",
            "check_out_accuracy",
            "check_out_address",
            "check_out_google_map_link",
            "check_out_map_url",
            "status",
            "notes",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "date",
            "check_in_google_map_link",
            "check_in_map_url",
            "check_out_google_map_link",
            "check_out_map_url",
            "created_at",
            "updated_at",
        ]


class DailyTargetSerializer(serializers.ModelSerializer):
    agent_name = serializers.CharField(source="agent.get_full_name", read_only=True)
    agent_username = serializers.CharField(source="agent.username", read_only=True)
    assigned_by_name = serializers.CharField(
        source="assigned_by.get_full_name", read_only=True
    )

    class Meta:
        model = DailyTarget
        fields = [
            "id",
            "agent",
            "agent_id",
            "agent_username",
            "agent_name",
            "date",
            "target_cash_amount",
            "target_donations_count",
            "target_product_units",
            "notes",
            "assigned_by",
            "assigned_by_name",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "assigned_by", "assigned_by_name", "created_at", "updated_at"]


class AgentDailyTargetProgressSerializer(serializers.ModelSerializer):
    """
    Workflow:
    'Attendance' -> 'Display Today's Target' -> 'View Daily Target'
    Combines target goals with real-time achieved metrics.
    """

    achieved_cash_amount = serializers.SerializerMethodField()
    achieved_donations_count = serializers.SerializerMethodField()
    achieved_product_units = serializers.SerializerMethodField()
    cash_completion_percentage = serializers.SerializerMethodField()
    count_completion_percentage = serializers.SerializerMethodField()
    is_cash_target_met = serializers.SerializerMethodField()

    class Meta:
        model = DailyTarget
        fields = [
            "id",
            "date",
            "target_cash_amount",
            "target_donations_count",
            "target_product_units",
            "notes",
            "achieved_cash_amount",
            "achieved_donations_count",
            "achieved_product_units",
            "cash_completion_percentage",
            "count_completion_percentage",
            "is_cash_target_met",
        ]

    def _get_today_donations(self, obj):
        if not hasattr(self, "_donations_cache"):
            self._donations_cache = Donation.objects.filter(
                agent=obj.agent, created_at__date=obj.date
            )
        return self._donations_cache

    @extend_schema_field(serializers.DecimalField(max_digits=12, decimal_places=2))
    def get_achieved_cash_amount(self, obj):
        donations = self._get_today_donations(obj)
        val = donations.filter(donation_type="CASH").aggregate(total=Sum("amount"))[
            "total"
        ]
        return val or Decimal("0.00")

    @extend_schema_field(serializers.IntegerField())
    def get_achieved_donations_count(self, obj):
        return self._get_today_donations(obj).count()

    @extend_schema_field(serializers.DecimalField(max_digits=10, decimal_places=2))
    def get_achieved_product_units(self, obj):
        donations = self._get_today_donations(obj)
        val = donations.filter(donation_type="PRODUCT").aggregate(
            total=Sum("quantity")
        )["total"]
        return val or Decimal("0.00")

    @extend_schema_field(serializers.FloatField())
    def get_cash_completion_percentage(self, obj):
        if not obj.target_cash_amount or obj.target_cash_amount <= 0:
            return 100.0 if self.get_achieved_cash_amount(obj) > 0 else 0.0
        achieved = self.get_achieved_cash_amount(obj)
        pct = float((achieved / obj.target_cash_amount) * 100)
        return round(min(pct, 100.0), 2)

    @extend_schema_field(serializers.FloatField())
    def get_count_completion_percentage(self, obj):
        if not obj.target_donations_count or obj.target_donations_count <= 0:
            return 100.0 if self.get_achieved_donations_count(obj) > 0 else 0.0
        achieved = self.get_achieved_donations_count(obj)
        pct = float((achieved / obj.target_donations_count) * 100)
        return round(min(pct, 100.0), 2)

    @extend_schema_field(serializers.BooleanField())
    def get_is_cash_target_met(self, obj):
        if not obj.target_cash_amount:
            return True
        return self.get_achieved_cash_amount(obj) >= obj.target_cash_amount
