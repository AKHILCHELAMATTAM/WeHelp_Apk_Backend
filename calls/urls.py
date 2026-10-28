from django.urls import path
from .views import (
    AdminCallLogListView,
    AdminCallLogSummaryView,
    AdminTelemarketingLeadListCreateView,
    AgentCallLogListCreateView,
    AgentCallLogDetailView,
    AgentCallSummaryView,
    AgentTelemarketingLeadsView,
)

urlpatterns = [
    # Agent telemarketing endpoints
    path("agent/calls/", AgentCallLogListCreateView.as_view(), name="agent-call-logs"),
    path("agent/calls/<int:pk>/", AgentCallLogDetailView.as_view(), name="agent-call-detail"),
    path("agent/calls/summary/", AgentCallSummaryView.as_view(), name="agent-call-summary"),
    path("agent/telemarketing/leads/", AgentTelemarketingLeadsView.as_view(), name="agent-leads"),

    # Admin telemarketing monitoring endpoints
    path("admin/calls/", AdminCallLogListView.as_view(), name="admin-call-logs"),
    path("admin/calls/summary/", AdminCallLogSummaryView.as_view(), name="admin-call-summary"),
    path("admin/telemarketing/leads/", AdminTelemarketingLeadListCreateView.as_view(), name="admin-leads"),
]
