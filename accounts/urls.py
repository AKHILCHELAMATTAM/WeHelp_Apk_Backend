from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .dashboard_views import AdminDashboardView, AgentDashboardView
from .views import (
    AdminAgentDetailView,
    AdminAgentListCreateView,
    AdminAgentStatusToggleView,
    DatabaseSeedView,
    RoleBasedLoginView,
    UserProfileView,
)

urlpatterns = [
    # Remote cloud initial setup / seed
    path("auth/setup-seed/", DatabaseSeedView.as_view(), name="auth-setup-seed"),
    # Auth endpoints
    path("auth/login/", RoleBasedLoginView.as_view(), name="auth-login"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("auth/profile/", UserProfileView.as_view(), name="auth-profile"),
    # Dashboards
    path("admin/dashboard/", AdminDashboardView.as_view(), name="admin-dashboard"),
    path("agent/dashboard/", AgentDashboardView.as_view(), name="agent-dashboard"),
    # Admin agent management endpoints
    path("admin/agents/", AdminAgentListCreateView.as_view(), name="admin-agents-list-create"),
    path("admin/agents/<int:pk>/", AdminAgentDetailView.as_view(), name="admin-agents-detail"),
    path(
        "admin/agents/<int:pk>/toggle-status/",
        AdminAgentStatusToggleView.as_view(),
        name="admin-agents-toggle-status",
    ),
]
