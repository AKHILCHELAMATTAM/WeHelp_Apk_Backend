class NormalizeSlashMiddleware:
    """
    Middleware to normalize URLs for REST APIs.
    If a client (Postman, Android Retrofit, cURL, etc.) calls a POST, PUT, PATCH,
    or GET endpoint without a trailing slash (e.g. /api/auth/login),
    this middleware normalizes request.path_info to /api/auth/login/
    so Django routes it directly without triggering CommonMiddleware's
    APPEND_SLASH 301 redirect or RuntimeError.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = request.path_info
        if not path.endswith("/"):
            # Don't append slash to static files or file downloads with extensions
            last_segment = path.split("/")[-1]
            if "." not in last_segment:
                request.path_info = path + "/"
        return self.get_response(request)
