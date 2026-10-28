from decimal import Decimal
from django import template
from django.db.models import Sum
from django.utils import timezone
from calls.models import CallLog

register = template.Library()


@register.simple_tag
def get_recent_call_logs(limit=10):
    """
    Returns the latest call logs with staff & contact details for the Admin Dashboard.
    """
    return CallLog.objects.select_related("agent").order_by("-created_at")[:limit]


@register.simple_tag
def get_telemarketing_kpis():
    """
    Calculates telemarketing KPIs for display on the Admin Dashboard.
    """
    today = timezone.localdate()
    today_calls = CallLog.objects.filter(created_at__date=today)

    today_count = today_calls.count()
    calls_30s = today_calls.filter(call_duration_seconds__gte=30).count()
    connected_count = today_calls.filter(
        status__in=["CONNECTED", "INTERESTED", "DONATION_PLEDGED"]
    ).count()
    pledged_sum = (
        today_calls.aggregate(total=Sum("pledged_amount"))["total"] or Decimal("0.00")
    )
    all_time_calls = CallLog.objects.count()

    return {
        "today_calls": today_count,
        "calls_30s": calls_30s,
        "connected_count": connected_count,
        "pledged_sum": float(pledged_sum),
        "all_time_calls": all_time_calls,
    }
