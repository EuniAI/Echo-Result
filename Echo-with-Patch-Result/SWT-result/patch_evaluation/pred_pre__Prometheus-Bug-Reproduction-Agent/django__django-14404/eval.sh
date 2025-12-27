#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD de32fe83a2e4a20887972c69a0693b94eb25a88b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff de32fe83a2e4a20887972c69a0693b94eb25a88b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_catch_all_redirect.py b/tests/test_catch_all_redirect.py
new file mode 100644
index 0000000000..cd768089c9
--- /dev/null
+++ b/tests/test_catch_all_redirect.py
@@ -0,0 +1,59 @@
+from django.contrib import admin
+from django.contrib.auth.models import User
+from django.test import TestCase, override_settings
+from django.test.client import RequestFactory
+from django.urls import path
+
+# A minimal, self-contained URLconf is used for test isolation.
+site = admin.AdminSite(name="admin")
+site.register(User)
+
+urlpatterns = [
+    path("admin/", site.urls),
+]
+
+
+# The test environment is configured with the minimal set of apps needed
+# for the admin site's URL resolver to function correctly.
+@override_settings(
+    ROOT_URLCONF=__name__,
+    INSTALLED_APPS=[
+        "django.contrib.admin",
+        "django.contrib.auth",
+        "django.contrib.contenttypes",
+        "django.contrib.sessions",
+    ],
+)
+class CatchAllViewForceScriptNameTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.user = User.objects.create_superuser("user", "user@example.com", "password")
+        cls.factory = RequestFactory()
+
+    def test_catch_all_redirect_respects_script_name(self):
+        """
+        The admin's catch_all_view should respect FORCE_SCRIPT_NAME when
+        redirecting a URL that is missing a trailing slash.
+        """
+        # A request object is created with RequestFactory to accurately simulate
+        # the SCRIPT_NAME and PATH_INFO environment of a real WSGI server.
+        request = self.factory.get("/admin/auth")
+        request.user = self.user
+
+        # Simulate the environment for a request to 'http://testserver/prefix/admin/auth'
+        request.META["SCRIPT_NAME"] = "/prefix"
+        request.path_info = "/admin/auth"
+        request.path = "/prefix/admin/auth"
+
+        # The request's urlconf is set to the test module's urlpatterns.
+        request.urlconf = __name__
+
+        # The view is called directly. For a request to '/admin/auth', the
+        # admin's URL resolver captures 'auth' and passes it as the 'url' argument.
+        response = site.catch_all_view(request, url="auth")
+
+        # The unpatched view builds the redirect from request.path_info,
+        # resulting in a redirect to '/admin/auth/'. The patched view uses
+        # request.get_full_path(), resulting in '/prefix/admin/auth/'.
+        self.assertEqual(response.status_code, 301)
+        self.assertEqual(response.url, "/prefix/admin/auth/")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/sites\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_catch_all_redirect
cat coverage.cover
git checkout de32fe83a2e4a20887972c69a0693b94eb25a88b
git apply /root/pre_state.patch
