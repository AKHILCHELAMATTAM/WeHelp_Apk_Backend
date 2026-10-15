from django.contrib.auth.models import AbstractUser, UserManager
from django.db import models


class CustomUserManager(UserManager):
    def create_superuser(self, username, email=None, password=None, **extra_fields):
        extra_fields.setdefault("role", "ADMIN")
        return super().create_superuser(username, email, password, **extra_fields)


class User(AbstractUser):
    objects = CustomUserManager()
    ROLE_CHOICES = (
        ("ADMIN", "Admin"),
        ("AGENT", "Agent"),
    )

    role = models.CharField(
        max_length=10,
        choices=ROLE_CHOICES,
        default="AGENT",
        help_text="User role in the system: Admin or Agent",
    )
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    employee_id = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        unique=True,
        help_text="Unique employee/agent code",
    )
    assigned_area = models.CharField(
        max_length=150,
        blank=True,
        null=True,
        help_text="Operational territory or assigned region",
    )
    is_active_agent = models.BooleanField(
        default=True,
        help_text="Specifies if agent is currently active for field duties",
    )
    created_by = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_agents",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "User"
        verbose_name_plural = "Users"

    def __str__(self):
        full_name = self.get_full_name()
        display = full_name if full_name else self.username
        return f"{display} ({self.role})"

    @property
    def is_admin_role(self):
        return self.role == "ADMIN" or self.is_superuser or self.is_staff

    @property
    def is_agent_role(self):
        return self.role == "AGENT"
