from django.contrib import admin

from .models import AgentLocation


@admin.register(AgentLocation)
class AgentLocationAdmin(admin.ModelAdmin):
    list_display = (
        "agent",
        "latitude",
        "longitude",
        "accuracy",
        "battery_level",
        "address",
        "recorded_at",
    )
    list_filter = ("agent", "recorded_at")
    search_fields = ("agent__username", "agent__first_name", "agent__last_name", "address")
    readonly_fields = ("created_at",)
