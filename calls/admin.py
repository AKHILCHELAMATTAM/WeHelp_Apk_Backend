from django.contrib import admin
from django.utils.html import format_html
from .models import CallLog, TelemarketingLead


@admin.register(CallLog)
class CallLogAdmin(admin.ModelAdmin):
    list_display = (
        "contact_name",
        "phone_number",
        "agent_display",
        "status_badge",
        "call_type_display",
        "duration_display",
        "pledged_amount_display",
        "follow_up_display",
        "created_at_display",
    )
    list_filter = (
        "status",
        "call_type",
        "lead_category",
        ("agent", admin.RelatedOnlyFieldListFilter),
        "created_at",
    )
    search_fields = (
        "contact_name",
        "phone_number",
        "agent__username",
        "agent__first_name",
        "agent__last_name",
        "notes",
    )
    date_hierarchy = "created_at"
    readonly_fields = ("created_at", "updated_at")
    list_per_page = 25

    fieldsets = (
        (
            "Call Information",
            {
                "fields": (
                    "agent",
                    "contact_name",
                    "phone_number",
                    "call_type",
                    "lead_category",
                )
            },
        ),
        (
            "Call Outcome & Disposition",
            {
                "fields": (
                    "status",
                    "call_duration_seconds",
                    "pledged_amount",
                    "follow_up_date",
                    "notes",
                )
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

    def agent_display(self, obj):
        full = obj.agent.get_full_name()
        display = full if full else obj.agent.username
        return format_html("<strong>{}</strong>", display)

    agent_display.short_description = "Staff / Agent"
    agent_display.admin_order_field = "agent__username"

    def status_badge(self, obj):
        colors = {
            "CONNECTED": ("#DEF7EC", "#03543F"),
            "INTERESTED": ("#E1EFFE", "#1E429F"),
            "DONATION_PLEDGED": ("#DEF7EC", "#0E9F6E"),
            "CALLBACK_REQUESTED": ("#FEF08A", "#854D0E"),
            "BUSY": ("#F3F4F6", "#4B5563"),
            "NO_ANSWER": ("#F3F4F6", "#4B5563"),
            "SWITCHED_OFF": ("#FEE2E2", "#991B1B"),
            "WRONG_NUMBER": ("#FEE2E2", "#991B1B"),
            "NOT_INTERESTED": ("#FEE2E2", "#991B1B"),
        }
        bg, fg = colors.get(obj.status, ("#F3F4F6", "#374151"))
        return format_html(
            '<span style="background-color: {}; color: {}; padding: 4px 10px; border-radius: 9999px; font-weight: 600; font-size: 11px; display: inline-block;">{}</span>',
            bg,
            fg,
            obj.get_status_display(),
        )

    status_badge.short_description = "Call Outcome"
    status_badge.admin_order_field = "status"

    def call_type_display(self, obj):
        type_icons = {
            "OUTGOING": "↗ Outgoing",
            "INCOMING": "↙ Incoming",
            "FOLLOW_UP": "↻ Follow-up",
        }
        return type_icons.get(obj.call_type, obj.call_type)

    call_type_display.short_description = "Type"

    def duration_display(self, obj):
        return obj.formatted_duration

    duration_display.short_description = "Duration"
    duration_display.admin_order_field = "call_duration_seconds"

    def pledged_amount_display(self, obj):
        if obj.pledged_amount and obj.pledged_amount > 0:
            return format_html(
                '<strong style="color: #059669;">₹{:,.2f}</strong>', obj.pledged_amount
            )
        return "-"

    pledged_amount_display.short_description = "Pledged"
    pledged_amount_display.admin_order_field = "pledged_amount"

    def follow_up_display(self, obj):
        if obj.follow_up_date:
            return obj.follow_up_date.strftime("%d %b %Y %H:%M")
        return "-"

    follow_up_display.short_description = "Follow-up"

    def created_at_display(self, obj):
        return obj.created_at.strftime("%d %b %Y, %I:%M %p")

    created_at_display.short_description = "Logged At"
    created_at_display.admin_order_field = "created_at"


@admin.register(TelemarketingLead)
class TelemarketingLeadAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "phone_number",
        "category",
        "status_badge",
        "assigned_agent_display",
        "total_calls_count",
        "last_called_at",
        "created_at",
    )
    list_filter = ("status", "category", "assigned_agent", "created_at")
    search_fields = ("name", "phone_number", "email", "city", "notes")
    list_per_page = 25

    def assigned_agent_display(self, obj):
        if obj.assigned_agent:
            return obj.assigned_agent.get_full_name() or obj.assigned_agent.username
        return format_html('<span style="color: #9CA3AF;">All Agents</span>')

    assigned_agent_display.short_description = "Assigned To"

    def status_badge(self, obj):
        colors = {
            "NEW": ("#E0E7FF", "#3730A3"),
            "IN_PROGRESS": ("#E1EFFE", "#1E429F"),
            "CALLBACK": ("#FEF08A", "#854D0E"),
            "CONVERTED": ("#DEF7EC", "#03543F"),
            "DO_NOT_CALL": ("#FEE2E2", "#991B1B"),
        }
        bg, fg = colors.get(obj.status, ("#F3F4F6", "#374151"))
        return format_html(
            '<span style="background-color: {}; color: {}; padding: 3px 8px; border-radius: 9999px; font-weight: 600; font-size: 11px;">{}</span>',
            bg,
            fg,
            obj.get_status_display(),
        )

    status_badge.short_description = "Lead Status"
