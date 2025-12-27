#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 55bcbd8d172b689811fae17cde2f09218dd74e9c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 55bcbd8d172b689811fae17cde2f09218dd74e9c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_admin_catch_all_redirect.py b/tests/test_admin_catch_all_redirect.py
new file mode 100644
index 0000000000..1bac924cfe
--- /dev/null
+++ b/tests/test_admin_catch_all_redirect.py
@@ -0,0 +1,49 @@
+from django.contrib import admin
+from django.contrib.auth.models import User
+from django.test import TestCase, override_settings
+from django.urls import path
+
+# A minimal admin site and URLconf to make the test self-contained.
+# Registering a model ensures that a valid URL pattern exists, which is
+# necessary to trigger the redirect logic in catch_all_view.
+site = admin.AdminSite(name="admin")
+site.register(User)
+
+urlpatterns = [
+    path("admin/", site.urls),
+]
+
+
+@override_settings(ROOT_URLCONF=__name__)
+class CatchAllViewRedirectTests(TestCase):
+    @override_settings(APPEND_SLASH=True)
+    def test_catch_all_redirect_preserves_query_string(self):
+        """
+        The admin's catch-all view redirect for APPEND_SLASH should preserve
+        the query string.
+        """
+        staff_user = User.objects.create_superuser(
+            "staff", "staff@example.com", "password"
+        )
+        self.client.force_login(staff_user)
+
+        # A valid admin URL for the User model changelist, but without the
+        # trailing slash and with a query string.
+        url_without_slash_with_qs = "/admin/auth/user?id=123"
+
+        # The expected redirect location should have the trailing slash AND
+        # the query string.
+        expected_redirect_url = "/admin/auth/user/?id=123"
+
+        response = self.client.get(url_without_slash_with_qs)
+
+        # The bug is that the redirect location is `/admin/auth/user/` without
+        # the query string. This assertion will fail with the bug because the
+        # actual redirect URL doesn't match the expected one. The superuser
+        # can access the target page, so the target status code is 200.
+        self.assertRedirects(
+            response,
+            expected_redirect_url,
+            status_code=301,
+            target_status_code=200,
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/sites\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_admin_catch_all_redirect
cat coverage.cover
git checkout 55bcbd8d172b689811fae17cde2f09218dd74e9c
git apply /root/pre_state.patch
