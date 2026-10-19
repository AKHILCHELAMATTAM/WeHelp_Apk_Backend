from django.db import models
from django.db.models import Count, Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from drf_spectacular.utils import extend_schema, OpenApiParameter
from rest_framework import generics, serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminUserRole, IsAgentUserRole
from .models import Donation
from .serializers import (
    CashDonationCreateSerializer,
    DonationDetailSerializer,
    DonationUpdateSerializer,
    PaymentRecordSerializer,
    PaymentStatusUpdateSerializer,
    ProductDonationCreateSerializer,
)


class AgentCreateCashDonationView(APIView):
    """
    Agent workflow:
    'Donation Entry' -> 'Donation Type' -> 'Cash' -> 'Enter Cash Donation' -> 'Save Donation Record'
    """

    permission_classes = [IsAgentUserRole]
    serializer_class = CashDonationCreateSerializer

    @extend_schema(
        request=CashDonationCreateSerializer,
        responses={201: DonationDetailSerializer},
        description="Records a new cash/monetary donation entry and generates receipt.",
    )
    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        donation = serializer.save()
        return Response(
            {
                "message": "Cash donation record saved successfully.",
                "donation": DonationDetailSerializer(donation).data,
            },
            status=status.HTTP_201_CREATED,
        )


class AgentCreateProductDonationView(APIView):
    """
    Agent workflow:
    'Donation Entry' -> 'Donation Type' -> 'Products' -> 'Enter Product or Grocery Donation' -> 'Save Donation Record'
    """

    permission_classes = [IsAgentUserRole]
    serializer_class = ProductDonationCreateSerializer

    @extend_schema(
        request=ProductDonationCreateSerializer,
        responses={201: DonationDetailSerializer},
        description="Records a new in-kind product or grocery donation and generates receipt.",
    )
    def post(self, request, *args, **kwargs):
        serializer = self.serializer_class(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        donation = serializer.save()
        return Response(
            {
                "message": "Product / Grocery donation record saved successfully.",
                "donation": DonationDetailSerializer(donation).data,
            },
            status=status.HTTP_201_CREATED,
        )


class AgentDonationListView(generics.ListAPIView):
    """
    Agent endpoint: lists all donations collected by the authenticated agent.
    """

    permission_classes = [IsAgentUserRole]
    serializer_class = DonationDetailSerializer

    def get_queryset(self):
        queryset = Donation.objects.filter(agent=self.request.user)
        dtype = self.request.query_params.get("donation_type")
        date_str = self.request.query_params.get("date")

        if dtype:
            queryset = queryset.filter(donation_type=dtype.upper())
        if date_str:
            target_date = parse_date(date_str)
            if target_date:
                queryset = queryset.filter(created_at__date=target_date)

        return queryset

    @extend_schema(
        parameters=[
            OpenApiParameter(
                name="donation_type",
                type=str,
                description="Filter by CASH or PRODUCT",
            ),
            OpenApiParameter(
                name="date",
                type=str,
                description="Filter by date (YYYY-MM-DD)",
            ),
        ]
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class AgentDonationDetailUpdateView(generics.RetrieveUpdateAPIView):
    """
    Agent workflow:
    'Update Donation Details'
    Retrieves or updates details of a donation previously entered by this agent.
    """

    permission_classes = [IsAgentUserRole]

    def get_serializer_class(self):
        if self.request.method in ["PUT", "PATCH"]:
            return DonationUpdateSerializer
        return DonationDetailSerializer

    def get_queryset(self):
        return Donation.objects.filter(agent=self.request.user)


class AgentDonationsSummaryView(APIView):
    """
    Returns today's and all-time donation summary for the logged-in agent.
    """

    permission_classes = [IsAgentUserRole]

    @extend_schema(
        responses={200: serializers.DictField()},
        description="Returns today's and all-time donation summary for the logged-in agent.",
    )
    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        agent = request.user

        today_cash = (
            Donation.objects.filter(
                agent=agent, donation_type="CASH", created_at__date=today
            ).aggregate(total=Sum("amount"))["total"]
            or 0.00
        )

        today_cash_count = Donation.objects.filter(
            agent=agent, donation_type="CASH", created_at__date=today
        ).count()

        today_product_count = Donation.objects.filter(
            agent=agent, donation_type="PRODUCT", created_at__date=today
        ).count()

        today_product_qty = (
            Donation.objects.filter(
                agent=agent, donation_type="PRODUCT", created_at__date=today
            ).aggregate(total=Sum("quantity"))["total"]
            or 0.00
        )

        return Response(
            {
                "date": today,
                "today": {
                    "cash_amount": today_cash,
                    "cash_donations_count": today_cash_count,
                    "product_donations_count": today_product_count,
                    "product_total_quantity": today_product_qty,
                    "total_donations_today": today_cash_count + today_product_count,
                },
            }
        )


# --- ADMIN VIEWS ---


class AdminDonationListView(generics.ListAPIView):
    """
    Admin endpoint to view and filter all donations.
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = DonationDetailSerializer

    def get_queryset(self):
        queryset = Donation.objects.all().select_related("agent", "verified_by")
        agent_id = self.request.query_params.get("agent_id")
        dtype = self.request.query_params.get("donation_type")
        date_str = self.request.query_params.get("date")
        search = self.request.query_params.get("search")

        if agent_id:
            queryset = queryset.filter(agent_id=agent_id)
        if dtype:
            queryset = queryset.filter(donation_type=dtype.upper())
        if date_str:
            target_date = parse_date(date_str)
            if target_date:
                queryset = queryset.filter(created_at__date=target_date)
        if search:
            queryset = queryset.filter(
                models.Q(receipt_number__icontains=search)
                | models.Q(donor_name__icontains=search)
                | models.Q(donor_phone__icontains=search)
                | models.Q(product_name__icontains=search)
            )

        return queryset

    @extend_schema(
        parameters=[
            OpenApiParameter(name="agent_id", type=int, description="Filter by Agent ID"),
            OpenApiParameter(name="donation_type", type=str, description="CASH or PRODUCT"),
            OpenApiParameter(name="date", type=str, description="Date filter (YYYY-MM-DD)"),
            OpenApiParameter(name="search", type=str, description="Search receipt, donor, or product"),
        ]
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class AdminDonationDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Admin endpoint to view, edit, or delete any donation record.
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = DonationDetailSerializer
    queryset = Donation.objects.all()


class AdminVerifyDonationView(APIView):
    """
    Admin endpoint to verify a donation record.
    """

    permission_classes = [IsAdminUserRole]

    @extend_schema(
        request=None,
        responses={200: DonationDetailSerializer},
        description="Admin endpoint to verify a donation record.",
    )
    def post(self, request, pk, *args, **kwargs):
        try:
            donation = Donation.objects.get(pk=pk)
        except Donation.DoesNotExist:
            return Response(
                {"detail": "Donation record not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        donation.status = "VERIFIED"
        donation.verified_by = request.user
        donation.save(update_fields=["status", "verified_by", "updated_at"])

        return Response(
            {
                "message": f"Donation {donation.receipt_number} has been verified.",
                "donation": DonationDetailSerializer(donation).data,
            },
            status=status.HTTP_200_OK,
        )


class AdminPaymentRecordsView(generics.ListAPIView):
    """
    Admin workflow:
    'Payment Details' -> 'View or Manage Payment Records'
    Lists cash payment transactions with payment modes and settlement status.
    """

    permission_classes = [IsAdminUserRole]
    serializer_class = PaymentRecordSerializer

    def get_queryset(self):
        queryset = Donation.objects.filter(donation_type="CASH").select_related("agent")
        payment_mode = self.request.query_params.get("payment_mode")
        payment_status = self.request.query_params.get("payment_status")
        agent_id = self.request.query_params.get("agent_id")
        date_str = self.request.query_params.get("date")

        if payment_mode:
            queryset = queryset.filter(payment_mode=payment_mode.upper())
        if payment_status:
            queryset = queryset.filter(payment_status=payment_status.upper())
        if agent_id:
            queryset = queryset.filter(agent_id=agent_id)
        if date_str:
            target_date = parse_date(date_str)
            if target_date:
                queryset = queryset.filter(created_at__date=target_date)

        return queryset

    @extend_schema(
        parameters=[
            OpenApiParameter(name="payment_mode", type=str, description="CASH, UPI, CARD, BANK_TRANSFER, CHEQUE"),
            OpenApiParameter(name="payment_status", type=str, description="COMPLETED, PENDING, FAILED, REFUNDED"),
            OpenApiParameter(name="agent_id", type=int, description="Filter by Agent ID"),
            OpenApiParameter(name="date", type=str, description="Filter by date (YYYY-MM-DD)"),
        ]
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class AdminPaymentRecordDetailView(generics.RetrieveUpdateAPIView):
    """
    Admin workflow:
    'Manage Payment Records' - update settlement status or transaction reference.
    """

    permission_classes = [IsAdminUserRole]
    queryset = Donation.objects.filter(donation_type="CASH")

    def get_serializer_class(self):
        if self.request.method in ["PUT", "PATCH"]:
            return PaymentStatusUpdateSerializer
        return PaymentRecordSerializer


class AdminPaymentSummaryView(APIView):
    """
    Admin financial summary: total revenue, payment mode breakdowns, today vs overall collections.
    """

    permission_classes = [IsAdminUserRole]

    @extend_schema(
        responses={200: serializers.DictField()},
        description="Admin financial summary: total revenue, payment mode breakdowns, today vs overall collections.",
    )
    def get(self, request, *args, **kwargs):
        today = timezone.localdate()

        total_cash_all_time = (
            Donation.objects.filter(
                donation_type="CASH", payment_status="COMPLETED"
            ).aggregate(total=Sum("amount"))["total"]
            or 0.00
        )

        today_cash = (
            Donation.objects.filter(
                donation_type="CASH",
                payment_status="COMPLETED",
                created_at__date=today,
            ).aggregate(total=Sum("amount"))["total"]
            or 0.00
        )

        mode_breakdown = (
            Donation.objects.filter(donation_type="CASH", payment_status="COMPLETED")
            .values("payment_mode")
            .annotate(total_amount=Sum("amount"), count=Count("id"))
            .order_by("-total_amount")
        )

        status_breakdown = (
            Donation.objects.filter(donation_type="CASH")
            .values("payment_status")
            .annotate(count=Count("id"), total_amount=Sum("amount"))
        )

        return Response(
            {
                "today_collection": today_cash,
                "total_collection_all_time": total_cash_all_time,
                "payment_mode_breakdown": list(mode_breakdown),
                "payment_status_breakdown": list(status_breakdown),
            }
        )


from .models import BankDetail
from .serializers import BankDetailSerializer


class AgentBankDetailView(APIView):
    """
    Returns active organization bank account details for UPI/QR and bank transfer collection.
    Accessible to authenticated agents.
    """

    permission_classes = [IsAgentUserRole]

    @extend_schema(
        responses={200: BankDetailSerializer},
        description="Returns active organization bank account details for donation collection.",
    )
    def get(self, request, *args, **kwargs):
        bank_detail = BankDetail.objects.filter(is_active=True).first()
        if not bank_detail:
            return Response(
                {
                    "account_holder_name": "WeHelp Foundation",
                    "bank_name": "Bank of Baroda",
                    "account_number": "84278100000006",
                    "ifsc_code": "BARB0VJIDUK",
                    "account_type": "Current Account",
                    "upi_id": "wehelp.donations@upi",
                    "branch_name": "Main Branch",
                    "is_active": True,
                }
            )
        serializer = BankDetailSerializer(bank_detail)
        return Response(serializer.data)


class AdminBankDetailView(APIView):
    """
    Allows administrators to view and configure organization bank account details.
    """

    permission_classes = [IsAdminUserRole]

    @extend_schema(
        responses={200: BankDetailSerializer},
        description="Admin view for organization bank account details.",
    )
    def get(self, request, *args, **kwargs):
        bank_detail = BankDetail.objects.filter(is_active=True).first()
        if not bank_detail:
            bank_detail = BankDetail.objects.create(
                account_holder_name="WeHelp Foundation",
                bank_name="Bank of Baroda",
                account_number="84278100000006",
                ifsc_code="BARB0VJIDUK",
                account_type="Current Account",
                upi_id="wehelp.donations@upi",
                branch_name="Main Branch",
                is_active=True,
            )
        serializer = BankDetailSerializer(bank_detail)
        return Response(serializer.data)

    @extend_schema(
        request=BankDetailSerializer,
        responses={200: BankDetailSerializer},
        description="Admin update for organization bank account details.",
    )
    def put(self, request, *args, **kwargs):
        bank_detail = BankDetail.objects.filter(is_active=True).first()
        if not bank_detail:
            serializer = BankDetailSerializer(data=request.data)
        else:
            serializer = BankDetailSerializer(
                bank_detail, data=request.data, partial=True
            )
        serializer.is_valid(raise_exception=True)
        saved = serializer.save()
        return Response(BankDetailSerializer(saved).data)

