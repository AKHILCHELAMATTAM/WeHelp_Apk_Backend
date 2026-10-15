from django.conf import settings
from django.db import models
from django.utils import timezone


class Attendance(models.Model):
    """
    Stores daily attendance records for agents with check-in/out timestamps and locations.
    Matches workflow:
    'Attendance'
    """

    STATUS_CHOICES = (
        ("PRESENT", "Present"),
        ("HALF_DAY", "Half Day"),
        ("ABSENT", "Absent"),
    )

    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="attendances",
        limit_choices_to={"role": "AGENT"},
    )
    date = models.DateField(default=timezone.localdate)
    check_in_time = models.DateTimeField(null=True, blank=True)
    check_out_time = models.DateTimeField(null=True, blank=True)
    check_in_latitude = models.FloatField(null=True, blank=True)
    check_in_longitude = models.FloatField(null=True, blank=True)
    check_in_address = models.CharField(max_length=255, blank=True, null=True)
    check_out_latitude = models.FloatField(null=True, blank=True)
    check_out_longitude = models.FloatField(null=True, blank=True)
    check_out_address = models.CharField(max_length=255, blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="PRESENT")
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-date", "-created_at"]
        unique_together = ("agent", "date")
        verbose_name = "Attendance Record"
        verbose_name_plural = "Attendance Records"

    def __str__(self):
        return f"{self.agent.username} - {self.date} ({self.status})"


class DailyTarget(models.Model):
    """
    Stores day-wise targets assigned to field agents.
    Matches workflow:
    'Attendance' -> 'Display Today's Target' -> 'View Daily Target'
    """

    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="daily_targets",
        limit_choices_to={"role": "AGENT"},
    )
    date = models.DateField(default=timezone.localdate)
    target_cash_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0.00,
        help_text="Target cash donation amount to collect for the day",
    )
    target_donations_count = models.IntegerField(
        default=0,
        help_text="Target number of successful donation entries for the day",
    )
    target_product_units = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Target quantity of products or grocery items to collect",
    )
    notes = models.TextField(blank=True, null=True, help_text="Specific focus/instructions for today")
    assigned_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="assigned_targets",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-date"]
        unique_together = ("agent", "date")
        verbose_name = "Daily Target"
        verbose_name_plural = "Daily Targets"

    def __str__(self):
        return f"Target for {self.agent.username} on {self.date}: Cash {self.target_cash_amount}"
