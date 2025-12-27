#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9b224579875e30203d079cc2fee83b116d98eb78 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9b224579875e30203d079cc2fee83b116d98eb78
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_session_authentication.py b/tests/auth_tests/test_session_authentication.py
new file mode 100644
index 0000000000..22ce967220
--- /dev/null
+++ b/tests/auth_tests/test_session_authentication.py
@@ -0,0 +1,45 @@
+from django.contrib.auth import SESSION_KEY
+from django.contrib.auth.models import User
+from django.test import TestCase, override_settings
+from django.urls import reverse
+
+
+class SessionAuthenticationTest(TestCase):
+    """
+    Tests for session authentication with SECRET_KEY rotation.
+    """
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.username = "testuser"
+        cls.password = "testpass"
+        # is_staff=True is required to access the admin index.
+        cls.user = User.objects.create_user(
+            username=cls.username,
+            password=cls.password,
+            is_staff=True,
+        )
+
+    @override_settings(SECRET_KEY="old-secret")
+    def test_secret_key_fallback_is_used_for_session(self):
+        """
+        Tests that SECRET_KEY_FALLBACKS is used for session authentication,
+        allowing users to stay logged in after a key rotation.
+        """
+        # Log in with the old secret key.
+        self.client.login(username=self.username, password=self.password)
+        # Sanity check that the user is logged in.
+        self.assertEqual(self.client.session[SESSION_KEY], str(self.user.pk))
+
+        # After key rotation, the session should still be valid by using the
+        # fallback key.
+        with override_settings(
+            SECRET_KEY="new-secret",
+            SECRET_KEY_FALLBACKS=["old-secret"],
+        ):
+            # A request to a view that accesses request.user will trigger the
+            # session auth hash check.
+            response = self.client.get(reverse("admin:index"), follow=True)
+            # This assertion fails because the session hash isn't validated
+            # against the fallback keys, logging the user out.
+            self.assertTrue(response.context["user"].is_authenticated)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/base_user\.py|django/contrib/auth/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_session_authentication
cat coverage.cover
git checkout 9b224579875e30203d079cc2fee83b116d98eb78
git apply /root/pre_state.patch
