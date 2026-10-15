from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response


@extend_schema(
    responses={200: serializers.DictField()},
    description="Interactive catalog of all available API endpoints in the system.",
)
@api_view(["GET"])
@permission_classes([AllowAny])
def api_root_index(request):
    """
    Overview of API endpoints available in the system.
    """
    return Response(
        {
            "system": "Field Agent & Donation Management Backend API",
            "documentation": {
                "swagger_ui": request.build_absolute_uri("/api/docs/"),
                "redoc": request.build_absolute_uri("/api/redoc/"),
                "openapi_schema": request.build_absolute_uri("/api/schema/"),
            },
            "auth_endpoints": {
                "role_login": request.build_absolute_uri("/api/auth/login/"),
                "token_refresh": request.build_absolute_uri("/api/auth/token/refresh/"),
                "profile": request.build_absolute_uri("/api/auth/profile/"),
            },
            "admin_endpoints": {
                "dashboard": request.build_absolute_uri("/api/admin/dashboard/"),
                "agent_creation_and_list": request.build_absolute_uri("/api/admin/agents/"),
                "live_location_tracking": request.build_absolute_uri("/api/admin/tracking/live/"),
                "donations_list": request.build_absolute_uri("/api/admin/donations/"),
                "payment_records": request.build_absolute_uri("/api/admin/payments/records/"),
                "payment_summary": request.build_absolute_uri("/api/admin/payments/summary/"),
                "attendance_records": request.build_absolute_uri("/api/admin/attendance/"),
                "targets_management": request.build_absolute_uri("/api/admin/targets/"),
                "leaves_management": request.build_absolute_uri("/api/admin/leaves/"),
            },
            "agent_endpoints": {
                "dashboard": request.build_absolute_uri("/api/agent/dashboard/"),
                "send_location": request.build_absolute_uri("/api/agent/location/"),
                "cash_donation_entry": request.build_absolute_uri("/api/agent/donations/cash/"),
                "product_donation_entry": request.build_absolute_uri("/api/agent/donations/product/"),
                "donations_list": request.build_absolute_uri("/api/agent/donations/"),
                "attendance_check_in": request.build_absolute_uri("/api/agent/attendance/check-in/"),
                "attendance_check_out": request.build_absolute_uri("/api/agent/attendance/check-out/"),
                "today_target": request.build_absolute_uri("/api/agent/target/today/"),
                "leave_request_submit": request.build_absolute_uri("/api/agent/leaves/"),
            },
        }
    )


# Django Admin branding
admin.site.site_header = "WeHelp Administration"
admin.site.site_title = "WeHelp Admin Portal"
admin.site.index_title = "Welcome to WeHelp Management Portal"


urlpatterns = [
    path("", api_root_index, name="api-root-index"),
    path("admin/", admin.site.urls),
    # Swagger & OpenAPI documentation
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    path("api/redoc/", SpectacularRedocView.as_view(url_name="schema"), name="redoc"),
    # Core app URLs
    path("api/", include("accounts.urls")),
    path("api/", include("tracking.urls")),
    path("api/", include("donations.urls")),
    path("api/", include("attendance.urls")),
    path("api/", include("leaves.urls")),
]
