from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = (
        "username",
        "email",
        "role",
        "employee_id",
        "assigned_area",
        "is_active_agent",
        "is_active",
        "is_staff",
    )
    list_filter = ("role", "is_active_agent", "is_active", "is_staff")
    fieldsets = BaseUserAdmin.fieldsets + (
        (
            "Agent & Role Information",
            {
                "fields": (
                    "role",
                    "phone_number",
                    "employee_id",
                    "assigned_area",
                    "is_active_agent",
                    "created_by",
                )
            },
        ),
    )
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        (
            "Agent & Role Information",
            {
                "fields": (
                    "role",
                    "phone_number",
                    "employee_id",
                    "assigned_area",
                    "is_active_agent",
                )
            },
        ),
    )
