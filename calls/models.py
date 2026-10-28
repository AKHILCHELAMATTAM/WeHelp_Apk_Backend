from decimal import Decimal
from django.conf import settings
from django.db import models
from django.utils import timezone


class CallLog(models.Model):
    """
    Stores call logs recorded by telemarketing staff and field agents.
    Visible in the Admin Panel for monitoring agent call activity,
    lead outreach, and donation pledges.
    """

    CALL_TYPE_CHOICES = (
        ("OUTGOING", "Outgoing Call"),
        ("INCOMING", "Incoming Call"),
        ("FOLLOW_UP", "Follow-up Call"),
    )

    STATUS_CHOICES = (
        ("CONNECTED", "Connected / Spoke"),
        ("INTERESTED", "Interested"),
        ("DONATION_PLEDGED", "Donation Pledged"),
        ("CALLBACK_REQUESTED", "Call Back Later"),
        ("BUSY", "Busy"),
        ("NO_ANSWER", "No Answer / Ringing"),
        ("SWITCHED_OFF", "Switched Off / Unreachable"),
        ("WRONG_NUMBER", "Wrong Number"),
        ("NOT_INTERESTED", "Not Interested"),
    )

    CATEGORY_CHOICES = (
        ("DONOR", "Individual Donor"),
        ("SPONSOR", "Sponsor / Patron"),
        ("CORPORATE", "Corporate CSR"),
        ("VOLUNTEER", "Volunteer Lead"),
        ("GENERAL_PUBLIC", "General Public"),
    )

    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="call_logs",
        help_text="The telemarketing agent who handled the call",
    )
    contact_name = models.CharField(
        max_length=150,
        help_text="Name of the person or contact dialed",
    )
    phone_number = models.CharField(
        max_length=30,
        db_index=True,
        help_text="Phone number dialed (e.g. +91 9876543210)",
    )
    call_type = models.CharField(
        max_length=20,
        choices=CALL_TYPE_CHOICES,
        default="OUTGOING",
        help_text="Direction or purpose of call",
    )
    status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default="CONNECTED",
        help_text="Call outcome / disposition",
    )
    call_duration_seconds = models.PositiveIntegerField(
        default=0,
        help_text="Estimated or recorded call duration in seconds",
    )
    pledged_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00"),
        blank=True,
        null=True,
        help_text="Amount pledged for donation during this call (if any)",
    )
    notes = models.TextField(
        blank=True,
        default="",
        help_text="Remarks, donor feedback, or conversation summary",
    )
    follow_up_date = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Scheduled callback date and time (if requested)",
    )
    lead_category = models.CharField(
        max_length=50,
        choices=CATEGORY_CHOICES,
        default="DONOR",
        help_text="Category of contact/donor",
    )
    created_at = models.DateTimeField(
        default=timezone.now,
        db_index=True,
        help_text="Timestamp when the call was recorded",
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Telemarketing Call Log"
        verbose_name_plural = "Telemarketing Call Logs"

    def __str__(self):
        return f"{self.contact_name} ({self.phone_number}) - {self.get_status_display()} by {self.agent.username}"

    @property
    def formatted_duration(self):
        """Format duration in mm:ss or human-readable format."""
        if not self.call_duration_seconds:
            return "0s"
        mins = self.call_duration_seconds // 60
        secs = self.call_duration_seconds % 60
        if mins > 0:
            return f"{mins}m {secs}s"
        return f"{secs}s"


class TelemarketingLead(models.Model):
    """
    Lead / contact for telemarketing staff to call.
    Admin can upload or manage these leads, and agents can call them from the APK.
    """

    LEAD_STATUS_CHOICES = (
        ("NEW", "New Lead"),
        ("IN_PROGRESS", "In Progress"),
        ("CALLBACK", "Callback Scheduled"),
        ("CONVERTED", "Donation Converted"),
        ("DO_NOT_CALL", "Do Not Call"),
    )

    name = models.CharField(max_length=150, help_text="Full name of the contact / lead")
    phone_number = models.CharField(max_length=30, unique=True, db_index=True)
    email = models.EmailField(blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    category = models.CharField(
        max_length=50,
        choices=CallLog.CATEGORY_CHOICES,
        default="DONOR",
    )
    status = models.CharField(
        max_length=30,
        choices=LEAD_STATUS_CHOICES,
        default="NEW",
    )
    assigned_agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_leads",
        help_text="Specific agent assigned to call this lead (leave empty for pool)",
    )
    total_calls_count = models.PositiveIntegerField(default=0)
    last_called_at = models.DateTimeField(blank=True, null=True)
    notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Telemarketing Lead"
        verbose_name_plural = "Telemarketing Leads"

    def __str__(self):
        return f"{self.name} ({self.phone_number}) - {self.get_status_display()}"
