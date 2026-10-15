import uuid
from django.conf import settings
from django.db import models
from django.utils import timezone


def generate_receipt_number(prefix="DON"):
    date_str = timezone.now().strftime("%Y%m%d")
    random_code = uuid.uuid4().hex[:6].upper()
    return f"{prefix}-{date_str}-{random_code}"


class Donation(models.Model):
    """
    Handles Cash and Product/Grocery donations recorded by agents.
    Matches workflow:
    'Donation Entry' -> 'Donation Type' -> 'Cash' / 'Products' -> 'Save Donation Record' -> 'Update Donation Details'
    Admin:
    'Payment Details' -> 'View or Manage Payment Records'
    """

    DONATION_TYPE_CHOICES = (
        ("CASH", "Cash"),
        ("PRODUCT", "Product / Grocery"),
    )

    PAYMENT_MODE_CHOICES = (
        ("CASH", "Cash"),
        ("UPI", "UPI / QR"),
        ("CARD", "Debit / Credit Card"),
        ("BANK_TRANSFER", "Bank Transfer / NEFT"),
        ("CHEQUE", "Cheque"),
    )

    PAYMENT_STATUS_CHOICES = (
        ("COMPLETED", "Completed"),
        ("PENDING", "Pending"),
        ("FAILED", "Failed"),
        ("REFUNDED", "Refunded"),
    )

    STATUS_CHOICES = (
        ("SUBMITTED", "Submitted"),
        ("VERIFIED", "Verified"),
        ("CANCELLED", "Cancelled"),
    )

    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="donations",
        limit_choices_to={"role": "AGENT"},
    )
    donation_type = models.CharField(max_length=15, choices=DONATION_TYPE_CHOICES)
    receipt_number = models.CharField(
        max_length=36,
        unique=True,
        db_index=True,
        default=generate_receipt_number,
        help_text="Unique receipt number issued to donor",
    )

    # Donor details
    donor_name = models.CharField(max_length=120)
    donor_phone = models.CharField(max_length=20, blank=True, null=True)
    donor_email = models.EmailField(blank=True, null=True)
    donor_address = models.TextField(blank=True, null=True)

    # Cash Donation fields
    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Monetary donation amount (Cash donations)",
    )
    currency = models.CharField(max_length=10, default="INR")
    payment_mode = models.CharField(
        max_length=20,
        choices=PAYMENT_MODE_CHOICES,
        default="CASH",
        null=True,
        blank=True,
    )
    payment_status = models.CharField(
        max_length=20,
        choices=PAYMENT_STATUS_CHOICES,
        default="COMPLETED",
        help_text="Payment transaction settlement status",
    )
    transaction_reference = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="Bank transaction ID, UPI reference or Cheque number",
    )

    # Product / Grocery Donation fields
    product_name = models.CharField(
        max_length=150,
        blank=True,
        null=True,
        help_text="Name of donated item (e.g., Rice, Wheat, Blankets, School Books)",
    )
    product_category = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="Item category: Grocery, Food Kits, Clothes, Medical, etc.",
    )
    quantity = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Quantity of product/grocery item",
    )
    unit = models.CharField(
        max_length=30,
        blank=True,
        null=True,
        help_text="Unit of measure (e.g. kg, litres, packets, boxes, pieces)",
    )
    estimated_value = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Approximate monetary valuation of the donated items",
    )

    # Status & Audit
    status = models.CharField(
        max_length=20, choices=STATUS_CHOICES, default="SUBMITTED"
    )
    notes = models.TextField(blank=True, null=True)
    latitude = models.FloatField(
        null=True, blank=True, help_text="GPS latitude where donation was received"
    )
    longitude = models.FloatField(
        null=True, blank=True, help_text="GPS longitude where donation was received"
    )
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="verified_donations",
    )
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["agent", "-created_at"]),
            models.Index(fields=["donation_type", "-created_at"]),
            models.Index(fields=["payment_status"]),
        ]
        verbose_name = "Donation Record"
        verbose_name_plural = "Donation Records"

    def __str__(self):
        if self.donation_type == "CASH":
            return f"Cash ({self.amount} {self.currency}) by {self.donor_name} - {self.receipt_number}"
        return f"Product ({self.quantity} {self.unit} {self.product_name}) by {self.donor_name} - {self.receipt_number}"
