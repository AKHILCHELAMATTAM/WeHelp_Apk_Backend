from django.urls import path

from .views import (
    AdminLeaveDetailView,
    AdminLeaveListView,
    AdminLeaveReviewView,
    AgentLeaveDetailView,
    AgentLeaveListCreateView,
)

urlpatterns = [
    # Agent endpoints
    path("agent/leaves/", AgentLeaveListCreateView.as_view(), name="agent-leaves-list-create"),
    path("agent/leaves/<int:pk>/", AgentLeaveDetailView.as_view(), name="agent-leaves-detail"),
    # Admin endpoints
    path("admin/leaves/", AdminLeaveListView.as_view(), name="admin-leaves-list"),
    path("admin/leaves/<int:pk>/", AdminLeaveDetailView.as_view(), name="admin-leaves-detail"),
    path("admin/leaves/<int:pk>/review/", AdminLeaveReviewView.as_view(), name="admin-leaves-review"),
]
