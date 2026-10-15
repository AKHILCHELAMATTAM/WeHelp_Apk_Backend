from django.contrib import admin

from .models import Attendance, DailyTarget


@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = (
        "agent",
        "date",
        "check_in_time",
        "check_out_time",
        "status",
        "check_in_address",
    )
    list_filter = ("date", "status")
    search_fields = ("agent__username", "agent__first_name", "agent__last_name")


@admin.register(DailyTarget)
class DailyTargetAdmin(admin.ModelAdmin):
    list_display = (
        "agent",
        "date",
        "target_cash_amount",
        "target_donations_count",
        "target_product_units",
        "assigned_by",
    )
    list_filter = ("date",)
    search_fields = ("agent__username", "agent__first_name", "agent__last_name")
