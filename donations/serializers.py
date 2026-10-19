from decimal import Decimal
from rest_framework import serializers

from .models import Donation


class CashDonationCreateSerializer(serializers.ModelSerializer):
    """
    Agent workflow:
    'Donation Entry' -> 'Donation Type' -> 'Cash' -> 'Enter Cash Donation' -> 'Save Donation Record'
    """

    class Meta:
        model = Donation
        fields = [
            "donor_name",
            "donor_phone",
            "donor_email",
            "donor_address",
            "amount",
            "currency",
            "payment_mode",
            "transaction_reference",
            "notes",
            "latitude",
            "longitude",
        ]

    def validate_amount(self, value):
        if value is None or value <= Decimal("0.00"):
            raise serializers.ValidationError("Donation amount must be greater than zero.")
        return value

    def create(self, validated_data):
        agent = self.context["request"].user
        return Donation.objects.create(
            agent=agent,
            donation_type="CASH",
            payment_status="COMPLETED",
            **validated_data,
        )


class ProductDonationCreateSerializer(serializers.ModelSerializer):
    """
    Agent workflow:
    'Donation Entry' -> 'Donation Type' -> 'Products' -> 'Enter Product or Grocery Donation' -> 'Save Donation Record'
    """

    class Meta:
        model = Donation
        fields = [
            "donor_name",
            "donor_phone",
            "donor_email",
            "donor_address",
            "product_name",
            "product_category",
            "quantity",
            "unit",
            "estimated_value",
            "notes",
            "latitude",
            "longitude",
        ]

    def validate_quantity(self, value):
        if value is None or value <= Decimal("0.00"):
            raise serializers.ValidationError("Product quantity must be greater than zero.")
        return value

    def validate_product_name(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Product/Grocery item name is required.")
        return value.strip()

    def validate_unit(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Unit of measurement (e.g. kg, packets, boxes) is required.")
        return value.strip()

    def create(self, validated_data):
        agent = self.context["request"].user
        return Donation.objects.create(
            agent=agent,
            donation_type="PRODUCT",
            **validated_data,
        )


class DonationUpdateSerializer(serializers.ModelSerializer):
    """
    Agent workflow:
    'Update Donation Details'
    Allows updating donor details, quantities, notes, or payment reference.
    """

    class Meta:
        model = Donation
        fields = [
            "donor_name",
            "donor_phone",
            "donor_email",
            "donor_address",
            "amount",
            "payment_mode",
            "transaction_reference",
            "product_name",
            "product_category",
            "quantity",
            "unit",
            "estimated_value",
            "notes",
        ]


class DonationDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for donation records with agent and receipt info.
    """

    agent_id = serializers.IntegerField(source="agent.id", read_only=True)
    agent_name = serializers.CharField(source="agent.get_full_name", read_only=True)
    agent_username = serializers.CharField(source="agent.username", read_only=True)
    verified_by_name = serializers.CharField(
        source="verified_by.get_full_name", read_only=True
    )

    class Meta:
        model = Donation
        fields = [
            "id",
            "receipt_number",
            "donation_type",
            "agent_id",
            "agent_username",
            "agent_name",
            "donor_name",
            "donor_phone",
            "donor_email",
            "donor_address",
            "amount",
            "currency",
            "payment_mode",
            "payment_status",
            "transaction_reference",
            "product_name",
            "product_category",
            "quantity",
            "unit",
            "estimated_value",
            "status",
            "notes",
            "latitude",
            "longitude",
            "verified_by_name",
            "created_at",
            "updated_at",
        ]


class PaymentRecordSerializer(serializers.ModelSerializer):
    """
    Admin workflow:
    'Payment Details' -> 'View or Manage Payment Records'
    Specifically highlights cash transactions and financial payment tracking.
    """

    agent_name = serializers.CharField(source="agent.get_full_name", read_only=True)
    agent_username = serializers.CharField(source="agent.username", read_only=True)

    class Meta:
        model = Donation
        fields = [
            "id",
            "receipt_number",
            "agent_id",
            "agent_username",
            "agent_name",
            "donor_name",
            "donor_phone",
            "amount",
            "currency",
            "payment_mode",
            "payment_status",
            "transaction_reference",
            "status",
            "created_at",
            "updated_at",
        ]


class PaymentStatusUpdateSerializer(serializers.ModelSerializer):
    """
    Admin management: update payment settlement status.
    """

    class Meta:
        model = Donation
        fields = ["payment_status", "transaction_reference", "notes"]


from .models import BankDetail


class BankDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for organization bank account details displayed to field agents.
    """

    class Meta:
        model = BankDetail
        fields = [
            "id",
            "account_holder_name",
            "bank_name",
            "account_number",
            "ifsc_code",
            "account_type",
            "upi_id",
            "branch_name",
            "is_active",
            "updated_at",
        ]

