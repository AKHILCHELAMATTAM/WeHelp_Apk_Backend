from django.contrib import admin
from django.utils.html import format_html

from .models import AgentLocation


@admin.register(AgentLocation)
class AgentLocationAdmin(admin.ModelAdmin):
    list_display = (
        "agent",
        "latitude",
        "longitude",
        "map_column",
        "accuracy",
        "battery_level",
        "address",
        "recorded_at",
    )
    list_filter = ("agent", "recorded_at")
    search_fields = ("agent__username", "agent__first_name", "agent__last_name", "address")
    readonly_fields = ("map_button", "created_at")

    @admin.display(description="Map View")
    def map_column(self, obj):
        if obj.google_map_link:
            return format_html(
                '<a href="{url}" target="_blank" rel="noopener noreferrer" style="background:#0b57d0; color:#fff; padding:3px 7px; border-radius:4px; text-decoration:none; font-weight:600; font-size:11px;">📍 Open Map</a>',
                url=obj.google_map_link,
            )
        return "-"

    @admin.display(description="Google Map Navigation")
    def map_button(self, obj):
        if obj.google_map_link:
            return format_html(
                '<a href="{url}" target="_blank" rel="noopener noreferrer" style="color:#0b57d0; font-weight:bold; font-size:13px; text-decoration:underline;">📍 Open GPS Coordinates on Google Maps ({lat}, {lng})</a>',
                url=obj.google_map_link,
                lat=obj.latitude,
                lng=obj.longitude,
            )
        return "No GPS coordinates"
