from rest_framework import permissions


class IsAdminUserRole(permissions.BasePermission):
    """
    Allows access only to authenticated users who have ADMIN role or superuser status.
    """

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and (
                request.user.role == "ADMIN"
                or request.user.is_staff
                or request.user.is_superuser
            )
        )


class IsAgentUserRole(permissions.BasePermission):
    """
    Allows access only to authenticated users who have AGENT role.
    """

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.role == "AGENT"
            and request.user.is_active_agent
        )


class IsSelfOrAdmin(permissions.BasePermission):
    """
    Allows object access only to the user itself or admins.
    """

    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
        if (
            request.user.role == "ADMIN"
            or request.user.is_staff
            or request.user.is_superuser
        ):
            return True
        return obj == request.user or getattr(obj, "agent", None) == request.user
