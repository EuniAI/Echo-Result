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
diff --git a/tests/test_session_secret_key_rotation.py b/tests/test_session_secret_key_rotation.py
new file mode 100644
index 0000000000..dea6560848
--- /dev/null
+++ b/tests/test_session_secret_key_rotation.py
@@ -0,0 +1,37 @@
+from django.contrib.auth import get_user
+from django.contrib.auth.models import User
+from django.contrib.sessions.backends.db import SessionStore
+from django.http import HttpRequest
+from django.test import TestCase, override_settings
+
+
+@override_settings(
+    SESSION_ENGINE="django.contrib.sessions.backends.db",
+)
+class SessionSecretKeyRotationTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.user = User.objects.create_user("test_user", password="password")
+
+    def test_secret_key_fallbacks_used_for_session_hash(self):
+        # 1. Create a session with the old secret key.
+        with override_settings(SECRET_KEY="old-secret", SECRET_KEY_FALLBACKS=[]):
+            self.client.force_login(self.user)
+            session_key = self.client.session.session_key
+
+        # 2. After key rotation, the user should still be logged in.
+        with override_settings(
+            SECRET_KEY="new-secret",
+            SECRET_KEY_FALLBACKS=["old-secret"],
+        ):
+            request = HttpRequest()
+            # Load the session from the database using the key created with the
+            # old secret key.
+            request.session = SessionStore(session_key)
+            user = get_user(request)
+
+            # Before the fix, get_user() returns an AnonymousUser because the
+            # session hash doesn't validate against the new SECRET_KEY and
+            # fallbacks are not checked. After the fix, the fallback key is
+            # used, the hash matches, and the user is authenticated.
+            self.assertEqual(user, self.user)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/base_user\.py|django/contrib/auth/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_session_secret_key_rotation
cat coverage.cover
git checkout 9b224579875e30203d079cc2fee83b116d98eb78
git apply /root/pre_state.patch
