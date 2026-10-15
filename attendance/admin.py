from django.contrib import admin

from .models import Attendance, DailyTarget


from django.utils.html import format_html


@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = (
        "agent",
        "date",
        "status",
        "check_in_time",
        "check_in_map_column",
        "check_out_time",
        "check_out_map_column",
    )
    list_filter = ("status", "date", "agent")
    search_fields = (
        "agent__username",
        "agent__first_name",
        "agent__last_name",
        "check_in_address",
        "check_out_address",
    )
    readonly_fields = (
        "check_in_map_button",
        "check_out_map_button",
        "created_at",
        "updated_at",
    )
    fieldsets = (
        (
            "Attendance Details",
            {
                "fields": ("agent", "date", "status", "notes"),
            },
        ),
        (
            "Check-In Location (Exact GPS)",
            {
                "fields": (
                    "check_in_time",
                    "check_in_latitude",
                    "check_in_longitude",
                    "check_in_accuracy",
                    "check_in_address",
                    "check_in_map_button",
                ),
            },
        ),
        (
            "Check-Out Location (Exact GPS)",
            {
                "fields": (
                    "check_out_time",
                    "check_out_latitude",
                    "check_out_longitude",
                    "check_out_accuracy",
                    "check_out_address",
                    "check_out_map_button",
                ),
            },
        ),
        (
            "System Timestamps",
            {
                "fields": ("created_at", "updated_at"),
                "classes": ("collapse",),
            },
        ),
    )

    @admin.display(description="Check-In Map")
    def check_in_map_column(self, obj):
        if obj.check_in_latitude is not None and obj.check_in_longitude is not None:
            url = f"https://www.google.com/maps?q={obj.check_in_latitude},{obj.check_in_longitude}"
            label = obj.check_in_address[:20] if obj.check_in_address else f"{obj.check_in_latitude:.4f},{obj.check_in_longitude:.4f}"
            return format_html(
                '<a href="{url}" target="_blank" rel="noopener noreferrer" style="background:#0b57d0; color:#fff; padding:3px 7px; border-radius:4px; text-decoration:none; font-weight:600; font-size:11px;">📍 {label}</a>',
                url=url,
                label=label,
            )
        return "-"

    @admin.display(description="Check-Out Map")
    def check_out_map_column(self, obj):
        if obj.check_out_latitude is not None and obj.check_out_longitude is not None:
            url = f"https://www.google.com/maps?q={obj.check_out_latitude},{obj.check_out_longitude}"
            label = obj.check_out_address[:20] if obj.check_out_address else f"{obj.check_out_latitude:.4f},{obj.check_out_longitude:.4f}"
            return format_html(
                '<a href="{url}" target="_blank" rel="noopener noreferrer" style="background:#137333; color:#fff; padding:3px 7px; border-radius:4px; text-decoration:none; font-weight:600; font-size:11px;">📍 {label}</a>',
                url=url,
                label=label,
            )
        return "-"

    @admin.display(description="Google Maps View")
    def check_in_map_button(self, obj):
        if obj.check_in_google_map_link:
            return format_html(
                '<a href="{url}" target="_blank" rel="noopener noreferrer" style="color:#0b57d0; font-weight:bold; font-size:13px; text-decoration:underline;">📍 Open Check-In GPS Coordinates on Google Maps ({lat}, {lng})</a>',
                url=obj.check_in_google_map_link,
                lat=obj.check_in_latitude,
                lng=obj.check_in_longitude,
            )
        return "No Check-In Coordinates Available"

    @admin.display(description="Google Maps View")
    def check_out_map_button(self, obj):
        if obj.check_out_google_map_link:
            return format_html(
                '<a href="{url}" target="_blank" rel="noopener noreferrer" style="color:#137333; font-weight:bold; font-size:13px; text-decoration:underline;">📍 Open Check-Out GPS Coordinates on Google Maps ({lat}, {lng})</a>',
                url=obj.check_out_google_map_link,
                lat=obj.check_out_latitude,
                lng=obj.check_out_longitude,
            )
        return "No Check-Out Coordinates Available"


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
