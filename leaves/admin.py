from django.contrib import admin

from .models import LeaveRequest


@admin.register(LeaveRequest)
class LeaveRequestAdmin(admin.ModelAdmin):
    list_display = (
        "agent",
        "request_type",
        "start_date",
        "end_date",
        "total_days",
        "status",
        "reviewed_by",
        "reviewed_at",
    )
    list_filter = ("request_type", "status", "start_date")
    search_fields = ("agent__username", "agent__first_name", "agent__last_name", "reason")
