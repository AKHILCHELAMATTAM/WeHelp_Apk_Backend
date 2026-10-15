from django.urls import path

from .views import (
    AdminAgentLocationHistoryView,
    AdminLiveTrackingView,
    AgentLatestLocationView,
    AgentSendLocationView,
)

urlpatterns = [
    # Agent endpoint
    path("agent/location/", AgentSendLocationView.as_view(), name="agent-send-location"),
    path("agent/location/latest/", AgentLatestLocationView.as_view(), name="agent-latest-location"),
    # Admin endpoints
    path("admin/tracking/live/", AdminLiveTrackingView.as_view(), name="admin-tracking-live"),
    path(
        "admin/tracking/agents/<int:agent_id>/history/",
        AdminAgentLocationHistoryView.as_view(),
        name="admin-tracking-agent-history",
    ),
]
