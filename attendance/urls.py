from django.urls import path

from .views import (
    AdminAttendanceListView,
    AdminDailyTargetDetailView,
    AdminDailyTargetListCreateView,
    AgentAttendanceHistoryView,
    AgentCheckInView,
    AgentCheckOutView,
    AgentTodayAttendanceStatusView,
    AgentTodayTargetView,
)

urlpatterns = [
    # Agent attendance & target endpoints
    path("agent/attendance/check-in/", AgentCheckInView.as_view(), name="agent-check-in"),
    path("agent/attendance/check-out/", AgentCheckOutView.as_view(), name="agent-check-out"),
    path(
        "agent/attendance/status/",
        AgentTodayAttendanceStatusView.as_view(),
        name="agent-attendance-status",
    ),
    path(
        "agent/attendance/history/",
        AgentAttendanceHistoryView.as_view(),
        name="agent-attendance-history",
    ),
    path("agent/target/today/", AgentTodayTargetView.as_view(), name="agent-target-today"),
    # Admin attendance & target endpoints
    path("admin/attendance/", AdminAttendanceListView.as_view(), name="admin-attendance-list"),
    path("admin/targets/", AdminDailyTargetListCreateView.as_view(), name="admin-targets-list-create"),
    path(
        "admin/targets/<int:pk>/",
        AdminDailyTargetDetailView.as_view(),
        name="admin-target-detail",
    ),
]
