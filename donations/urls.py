from django.urls import path

from .views import (
    AdminDonationDetailView,
    AdminDonationListView,
    AdminPaymentRecordDetailView,
    AdminPaymentRecordsView,
    AdminPaymentSummaryView,
    AdminVerifyDonationView,
    AgentCreateCashDonationView,
    AgentCreateProductDonationView,
    AgentDonationDetailUpdateView,
    AgentDonationListView,
    AgentDonationsSummaryView,
)

urlpatterns = [
    # Agent donation entry endpoints
    path(
        "agent/donations/cash/",
        AgentCreateCashDonationView.as_view(),
        name="agent-donation-cash",
    ),
    path(
        "agent/donations/product/",
        AgentCreateProductDonationView.as_view(),
        name="agent-donation-product",
    ),
    path(
        "agent/donations/",
        AgentDonationListView.as_view(),
        name="agent-donations-list",
    ),
    path(
        "agent/donations/<int:pk>/",
        AgentDonationDetailUpdateView.as_view(),
        name="agent-donation-detail-update",
    ),
    path(
        "agent/donations/summary/",
        AgentDonationsSummaryView.as_view(),
        name="agent-donations-summary",
    ),
    # Admin donation management endpoints
    path(
        "admin/donations/",
        AdminDonationListView.as_view(),
        name="admin-donations-list",
    ),
    path(
        "admin/donations/<int:pk>/",
        AdminDonationDetailView.as_view(),
        name="admin-donation-detail",
    ),
    path(
        "admin/donations/<int:pk>/verify/",
        AdminVerifyDonationView.as_view(),
        name="admin-donation-verify",
    ),
    # Admin payment records endpoints
    path(
        "admin/payments/records/",
        AdminPaymentRecordsView.as_view(),
        name="admin-payments-records",
    ),
    path(
        "admin/payments/records/<int:pk>/",
        AdminPaymentRecordDetailView.as_view(),
        name="admin-payment-record-detail",
    ),
    path(
        "admin/payments/summary/",
        AdminPaymentSummaryView.as_view(),
        name="admin-payments-summary",
    ),
]
