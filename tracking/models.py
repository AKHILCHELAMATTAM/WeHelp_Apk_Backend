from django.conf import settings
from django.db import models
from django.utils import timezone


class AgentLocation(models.Model):
    """
    Stores GPS location coordinates captured from the Android device.
    Matches workflow:
    'Capture Agent Location' -> 'Send Location to Backend' -> 'Admin Can Track Agent'
    """

    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="locations",
        limit_choices_to={"role": "AGENT"},
    )
    latitude = models.FloatField(help_text="Latitude coordinate in decimal degrees")
    longitude = models.FloatField(help_text="Longitude coordinate in decimal degrees")
    accuracy = models.FloatField(
        null=True, blank=True, help_text="GPS accuracy in meters"
    )
    speed = models.FloatField(
        null=True, blank=True, help_text="Current movement speed (km/h)"
    )
    altitude = models.FloatField(null=True, blank=True, help_text="Altitude in meters")
    battery_level = models.IntegerField(
        null=True,
        blank=True,
        help_text="Device battery percentage at time of capture (0-100)",
    )
    address = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Human-readable address or landmark",
    )
    recorded_at = models.DateTimeField(
        default=timezone.now,
        help_text="Timestamp when GPS fix was recorded on device",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-recorded_at"]
        indexes = [
            models.Index(fields=["agent", "-recorded_at"]),
            models.Index(fields=["recorded_at"]),
        ]
        verbose_name = "Agent Location"
        verbose_name_plural = "Agent Locations"

    def __str__(self):
        return f"{self.agent.username} @ ({self.latitude}, {self.longitude}) at {self.recorded_at}"

    @property
    def google_map_link(self):
        """
        Returns direct Google Maps pin URL for the location fix.
        """
        if self.latitude is not None and self.longitude is not None:
            return f"https://www.google.com/maps?q={self.latitude},{self.longitude}"
        return None
