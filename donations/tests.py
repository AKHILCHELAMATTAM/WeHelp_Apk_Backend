from decimal import Decimal
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from donations.models import Donation


class DonationWorkflowTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_superuser(
            username="admin_donor",
            password="Password@123",
            role="ADMIN",
        )
        self.agent = User.objects.create_user(
            username="agent_donor",
            password="Password@123",
            role="AGENT",
            employee_id="AGT-DON-01",
        )
        self.cash_url = reverse("agent-donation-cash")
        self.product_url = reverse("agent-donation-product")
        self.admin_payments_url = reverse("admin-payments-records")

    def test_enter_cash_donation(self):
        """Workflow: Donation Entry -> Donation Type -> Cash -> Enter Cash Donation -> Save Donation Record"""
        self.client.force_authenticate(user=self.agent)
        payload = {
            "donor_name": "Suresh Raina",
            "donor_phone": "+91 9876501234",
            "amount": "5000.00",
            "payment_mode": "UPI",
            "transaction_reference": "UPI/12345678/REF",
            "notes": "Annual education scholarship contribution",
        }
        res = self.client.post(self.cash_url, payload)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Donation.objects.count(), 1)
        donation = Donation.objects.first()
        self.assertEqual(donation.donation_type, "CASH")
        self.assertEqual(donation.amount, Decimal("5000.00"))
        self.assertEqual(donation.donor_name, "Suresh Raina")
        self.assertTrue(donation.receipt_number.startswith("DON-"))

    def test_enter_product_donation(self):
        """Workflow: Donation Entry -> Donation Type -> Products -> Enter Product or Grocery Donation -> Save Donation Record"""
        self.client.force_authenticate(user=self.agent)
        payload = {
            "donor_name": "City Wholesale Grocery",
            "donor_phone": "+91 9811223344",
            "product_name": "Basmati Rice Bags",
            "product_category": "Grocery",
            "quantity": "50.00",
            "unit": "kg",
            "estimated_value": "3500.00",
            "notes": "Flood relief drive kit",
        }
        res = self.client.post(self.product_url, payload)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Donation.objects.count(), 1)
        donation = Donation.objects.first()
        self.assertEqual(donation.donation_type, "PRODUCT")
        self.assertEqual(donation.product_name, "Basmati Rice Bags")
        self.assertEqual(donation.quantity, Decimal("50.00"))
        self.assertEqual(donation.unit, "kg")

    def test_update_donation_details(self):
        """Workflow: Update Donation Details"""
        self.client.force_authenticate(user=self.agent)
        donation = Donation.objects.create(
            agent=self.agent,
            donation_type="CASH",
            donor_name="Vikram Singh",
            amount=Decimal("1000.00"),
            payment_mode="CASH",
        )
        url = reverse("agent-donation-detail-update", kwargs={"pk": donation.id})
        update_payload = {
            "donor_name": "Vikram Singh Rathore",
            "notes": "Updated donor full name and receipt copy dispatched via WhatsApp",
        }
        res = self.client.patch(url, update_payload)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        donation.refresh_from_db()
        self.assertEqual(donation.donor_name, "Vikram Singh Rathore")

    def test_admin_view_and_manage_payment_records(self):
        """Workflow: Admin Dashboard -> Payment Details -> View or Manage Payment Records"""
        Donation.objects.create(
            agent=self.agent,
            donation_type="CASH",
            donor_name="Corporate Donor Inc",
            amount=Decimal("25000.00"),
            payment_mode="BANK_TRANSFER",
            payment_status="PENDING",
            transaction_reference="NEFT-998877",
        )

        self.client.force_authenticate(user=self.admin)
        res = self.client.get(self.admin_payments_url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(len(res.data["results"]) >= 1)

        # Admin updates payment settlement status
        donation = Donation.objects.first()
        detail_url = reverse("admin-payment-record-detail", kwargs={"pk": donation.id})
        res = self.client.patch(detail_url, {"payment_status": "COMPLETED"})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        donation.refresh_from_db()
        self.assertEqual(donation.payment_status, "COMPLETED")

    def test_agent_retrieves_bank_details_gracefully_when_empty(self):
        """Agent retrieves default/graceful payload when no bank details created"""
        self.client.force_authenticate(user=self.agent)
        url = reverse("agent-bank-details")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["account_holder_name"], "WeHelp Foundation")
        self.assertEqual(res.data["account_number"], "84278100000006")

    def test_agent_retrieves_bank_details_when_configured(self):
        """Agent retrieves active bank details when configured by admin"""
        from donations.models import BankDetail

        BankDetail.objects.create(
            account_holder_name="WeHelp Foundation Trust",
            bank_name="State Bank of India",
            account_number="39912345678",
            ifsc_code="SBIN0001234",
            upi_id="wehelp@sbi",
            branch_name="Main City Branch",
            is_active=True,
        )

        self.client.force_authenticate(user=self.agent)
        url = reverse("agent-bank-details")
        res = self.client.get(url)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["bank_name"], "State Bank of India")
        self.assertEqual(res.data["account_number"], "39912345678")
        self.assertEqual(res.data["ifsc_code"], "SBIN0001234")

    def test_admin_updates_bank_details(self):
        """Admin configures or updates organization bank details"""
        self.client.force_authenticate(user=self.admin)
        url = reverse("admin-bank-details")
        payload = {
            "account_holder_name": "WeHelp Relief Trust",
            "bank_name": "HDFC Bank",
            "account_number": "50100234567890",
            "ifsc_code": "HDFC0000123",
            "upi_id": "wehelp.trust@hdfcbank",
        }
        res = self.client.put(url, payload)
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["account_number"], "50100234567890")

