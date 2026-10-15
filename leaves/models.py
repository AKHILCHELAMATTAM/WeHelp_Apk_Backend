from django.conf import settings
from django.db import models


class LeaveRequest(models.Model):
    """
    Manages Leave and Week-Off requests submitted by agents and reviewed by admin.
    Matches workflow:
    Agent: 'Leave or Week-Off Request' -> 'Submit Request to Admin' -> 'Admin Reviews Request' -> 'Approval or Rejection Status'
    Admin: 'Leave and Week-Off Management' -> 'View Agent Requests' -> 'Approve Request?' -> 'Approve Leave or Week-Off' / 'Reject Request'
    """

    REQUEST_TYPE_CHOICES = (
        ("LEAVE", "Leave"),
        ("WEEK_OFF", "Week Off"),
    )

    STATUS_CHOICES = (
        ("PENDING", "Pending"),
        ("APPROVED", "Approved"),
        ("REJECTED", "Rejected"),
    )

    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="leave_requests",
        limit_choices_to={"role": "AGENT"},
    )
    request_type = models.CharField(
        max_length=20,
        choices=REQUEST_TYPE_CHOICES,
        help_text="Type of request: LEAVE or WEEK_OFF",
    )
    start_date = models.DateField(help_text="First day of leave or week-off")
    end_date = models.DateField(help_text="Last day of leave or week-off")
    total_days = models.PositiveIntegerField(
        default=1, help_text="Total number of days requested"
    )
    reason = models.TextField(help_text="Reason for leave or week-off request")
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="PENDING",
        help_text="Current approval status",
    )
    admin_remarks = models.TextField(
        blank=True,
        null=True,
        help_text="Remarks/notes added by administrator during approval or rejection",
    )
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="reviewed_leaves",
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Leave Request"
        verbose_name_plural = "Leave Requests"

    def __str__(self):
        return f"{self.agent.username} - {self.request_type} ({self.start_date} to {self.end_date}) [{self.status}]"
