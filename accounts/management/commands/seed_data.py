from datetime import timedelta
from decimal import Decimal
from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import User
from attendance.models import Attendance, DailyTarget
from donations.models import Donation
from leaves.models import LeaveRequest
from tracking.models import AgentLocation


class Command(BaseCommand):
    help = "Populate database with sample Admin, Field Agents, Targets, Donations, and Attendance."

    def handle(self, *args, **options):
        self.stdout.write("Starting data seed...")

        # 1. Create Superuser / Admin
        admin_user, created = User.objects.get_or_create(
            username="admin",
            defaults={
                "email": "admin@ngo-foundation.org",
                "first_name": "System",
                "last_name": "Administrator",
                "role": "ADMIN",
                "is_staff": True,
                "is_superuser": True,
                "phone_number": "+91 9876543210",
                "employee_id": "EMP-ADM-001",
            },
        )
        if created:
            admin_user.set_password("Admin@1234")
            admin_user.save()
            self.stdout.write(self.style.SUCCESS("Created Admin: admin / Admin@1234"))
        else:
            self.stdout.write("Admin user already exists.")

        # 2. Create Field Agent 1
        agent1, created = User.objects.get_or_create(
            username="agent_rahul",
            defaults={
                "email": "rahul.sharma@ngo-foundation.org",
                "first_name": "Rahul",
                "last_name": "Sharma",
                "role": "AGENT",
                "phone_number": "+91 9811223344",
                "employee_id": "AGT-2026-001",
                "assigned_area": "North Zone - Sector 14, Delhi NCR",
                "is_active_agent": True,
                "created_by": admin_user,
            },
        )
        if created:
            agent1.set_password("Agent@1234")
            agent1.save()
            self.stdout.write(self.style.SUCCESS("Created Agent 1: agent_rahul / Agent@1234"))

        # 3. Create Field Agent 2
        agent2, created = User.objects.get_or_create(
            username="agent_priya",
            defaults={
                "email": "priya.verma@ngo-foundation.org",
                "first_name": "Priya",
                "last_name": "Verma",
                "role": "AGENT",
                "phone_number": "+91 9822334455",
                "employee_id": "AGT-2026-002",
                "assigned_area": "South Zone - Indiranagar, Bengaluru",
                "is_active_agent": True,
                "created_by": admin_user,
            },
        )
        if created:
            agent2.set_password("Agent@1234")
            agent2.save()
            self.stdout.write(self.style.SUCCESS("Created Agent 2: agent_priya / Agent@1234"))

        today = timezone.localdate()
        now = timezone.now()

        # 4. Set Daily Targets for today
        target1, _ = DailyTarget.objects.get_or_create(
            agent=agent1,
            date=today,
            defaults={
                "target_cash_amount": Decimal("10000.00"),
                "target_donations_count": 8,
                "target_product_units": Decimal("50.00"),
                "notes": "Targeted corporate sector drive today.",
                "assigned_by": admin_user,
            },
        )

        target2, _ = DailyTarget.objects.get_or_create(
            agent=agent2,
            date=today,
            defaults={
                "target_cash_amount": Decimal("8000.00"),
                "target_donations_count": 6,
                "target_product_units": Decimal("40.00"),
                "notes": "Focus on residential society donations.",
                "assigned_by": admin_user,
            },
        )

        # 5. Record Check-in for Agent 1
        att1, _ = Attendance.objects.get_or_create(
            agent=agent1,
            date=today,
            defaults={
                "check_in_time": now - timedelta(hours=4),
                "check_in_latitude": 28.7041,
                "check_in_longitude": 77.1025,
                "check_in_address": "Sector 14 Hub, Rohini, New Delhi",
                "status": "PRESENT",
            },
        )

        # 6. Add GPS Location records for live tracking
        AgentLocation.objects.create(
            agent=agent1,
            latitude=28.7045,
            longitude=77.1030,
            accuracy=4.5,
            battery_level=88,
            speed=1.2,
            address="Near City Center Mall, Sector 14, Delhi",
            recorded_at=now - timedelta(minutes=5),
        )

        AgentLocation.objects.create(
            agent=agent2,
            latitude=12.9716,
            longitude=77.5946,
            accuracy=5.0,
            battery_level=75,
            speed=0.0,
            address="100 Feet Road, Indiranagar, Bengaluru",
            recorded_at=now - timedelta(minutes=10),
        )

        # 7. Record Cash Donations
        Donation.objects.get_or_create(
            receipt_number="DON-20261014-C001",
            defaults={
                "agent": agent1,
                "donation_type": "CASH",
                "donor_name": "Ramesh Gupta",
                "donor_phone": "+91 9988776655",
                "donor_email": "ramesh.gupta@example.com",
                "donor_address": "Flat 302, Green Park Apartments, Delhi",
                "amount": Decimal("3500.00"),
                "currency": "INR",
                "payment_mode": "UPI",
                "payment_status": "COMPLETED",
                "transaction_reference": "UPI/98712344567/PAY",
                "status": "VERIFIED",
                "verified_by": admin_user,
                "notes": "Contribution for child education fund",
                "latitude": 28.7042,
                "longitude": 77.1028,
            },
        )

        Donation.objects.get_or_create(
            receipt_number="DON-20261014-C002",
            defaults={
                "agent": agent1,
                "donation_type": "CASH",
                "donor_name": "Anita Desai",
                "donor_phone": "+91 9877112233",
                "amount": Decimal("2000.00"),
                "currency": "INR",
                "payment_mode": "CASH",
                "payment_status": "COMPLETED",
                "status": "SUBMITTED",
                "notes": "Cash contribution collected in field",
                "latitude": 28.7050,
                "longitude": 77.1035,
            },
        )

        # 8. Record Product/Grocery Donation
        Donation.objects.get_or_create(
            receipt_number="DON-20261014-P001",
            defaults={
                "agent": agent1,
                "donation_type": "PRODUCT",
                "donor_name": "Aggarwal Department Store",
                "donor_phone": "+91 9123456780",
                "product_name": "Rice and Wheat Flour Bags",
                "product_category": "Grocery",
                "quantity": Decimal("25.00"),
                "unit": "kg",
                "estimated_value": Decimal("1500.00"),
                "status": "SUBMITTED",
                "notes": "Dry ration donation for community kitchen",
                "latitude": 28.7048,
                "longitude": 77.1031,
            },
        )

        # 9. Record Leave Requests (Pending & Approved)
        LeaveRequest.objects.get_or_create(
            agent=agent1,
            start_date=today + timedelta(days=5),
            end_date=today + timedelta(days=6),
            defaults={
                "request_type": "WEEK_OFF",
                "total_days": 2,
                "reason": "Family function over the weekend.",
                "status": "PENDING",
            },
        )

        LeaveRequest.objects.get_or_create(
            agent=agent2,
            start_date=today + timedelta(days=10),
            end_date=today + timedelta(days=11),
            defaults={
                "request_type": "LEAVE",
                "total_days": 2,
                "reason": "Personal medical checkup.",
                "status": "APPROVED",
                "admin_remarks": "Approved. Please handover pending receipts before leaving.",
                "reviewed_by": admin_user,
                "reviewed_at": now - timedelta(hours=1),
            },
        )

        self.stdout.write(self.style.SUCCESS("Data seeding completed successfully!"))
