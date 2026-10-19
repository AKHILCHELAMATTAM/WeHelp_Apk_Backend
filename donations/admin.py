from django.contrib import admin

from .models import Donation


@admin.register(Donation)
class DonationAdmin(admin.ModelAdmin):
    list_display = (
        "receipt_number",
        "donation_type",
        "agent",
        "donor_name",
        "amount",
        "currency",
        "payment_mode",
        "product_name",
        "quantity",
        "unit",
        "payment_status",
        "status",
        "created_at",
    )
    list_filter = (
        "donation_type",
        "payment_mode",
        "payment_status",
        "status",
        "created_at",
    )
    search_fields = (
        "receipt_number",
        "donor_name",
        "donor_phone",
        "agent__username",
        "product_name",
    )
    readonly_fields = ("receipt_number", "created_at", "updated_at")


from .models import BankDetail


@admin.register(BankDetail)
class BankDetailAdmin(admin.ModelAdmin):
    list_display = (
        "account_holder_name",
        "bank_name",
        "account_number",
        "ifsc_code",
        "upi_id",
        "branch_name",
        "is_active",
        "updated_at",
    )
    list_filter = ("is_active",)
    search_fields = ("account_holder_name", "bank_name", "account_number", "ifsc_code")

