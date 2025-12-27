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
diff --git a/tests/admin_views/test_catchall_view.py b/tests/admin_views/test_catchall_view.py
new file mode 100644
index 0000000000..0407c45a93
--- /dev/null
+++ b/tests/admin_views/test_catchall_view.py
@@ -0,0 +1,38 @@
+from django.contrib.auth.models import User
+from django.test import TestCase, override_settings
+from django.urls import reverse
+
+
+@override_settings(ROOT_URLCONF="admin_views.urls")
+class AdminSiteFinalCatchAllPatternTests(TestCase):
+    """
+    Verifies the behaviour of the admin catch-all view.
+    """
+
+    @override_settings(APPEND_SLASH=True)
+    def test_redirect_for_missing_slash_preserves_query_string(self):
+        """
+        The catch-all view should preserve the query string when redirecting
+        to append a slash.
+        """
+        superuser = User.objects.create_superuser(
+            "super", "super@example.com", "secret"
+        )
+        self.client.force_login(superuser)
+
+        # The example from the bug report is /admin/auth/foo?id=123. 'foo' is not a
+        # real model, so we use 'user' which is. The catch_all_view only
+        # redirects if the URL with a slash resolves.
+        url_with_slash = reverse("admin:auth_user_changelist")
+        url_without_slash = url_with_slash[:-1]
+
+        url_to_test = f"{url_without_slash}?id=123"
+        expected_redirect_url = f"{url_with_slash}?id=123"
+
+        response = self.client.get(url_to_test)
+        self.assertRedirects(
+            response,
+            expected_redirect_url,
+            status_code=301,
+            target_status_code=200,
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/sites\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_views.test_catchall_view
cat coverage.cover
git checkout 55bcbd8d172b689811fae17cde2f09218dd74e9c
git apply /root/pre_state.patch
