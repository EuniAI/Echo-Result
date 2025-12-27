#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6e9c5ee88fc948e05b4a7d9f82a8861ed2b0343d >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6e9c5ee88fc948e05b4a7d9f82a8861ed2b0343d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/sessions_tests/test_legacy_session_encoding.py b/tests/sessions_tests/test_legacy_session_encoding.py
new file mode 100644
index 0000000000..a745fa2ad7
--- /dev/null
+++ b/tests/sessions_tests/test_legacy_session_encoding.py
@@ -0,0 +1,43 @@
+from django.contrib.sessions.backends.db import SessionStore as DatabaseSession
+from django.test import TestCase, ignore_warnings, override_settings
+from django.utils.deprecation import RemovedInDjango40Warning
+
+
+class SessionTestsMixin:
+    # This does not inherit from TestCase to avoid any tests being run with this
+    # class, which wouldn't work, and to allow different TestCase subclasses to
+    # be used.
+
+    backend = None  # subclasses must specify
+
+    def setUp(self):
+        self.session = self.backend()
+
+    def tearDown(self):
+        # NB: be careful to delete any sessions created; stale sessions fill up
+        # the /tmp (with some backends) and eventually overwhelm it after lots
+        # of runs (think buildbots)
+        self.session.delete()
+
+    @ignore_warnings(category=RemovedInDjango40Warning)
+    @override_settings(
+        DEFAULT_HASHING_ALGORITHM='sha1',
+        SECRET_KEY='django_tests_secret_key',
+    )
+    def test_legacy_encode_sha1(self):
+        """
+        With DEFAULT_HASHING_ALGORITHM='sha1', encode() uses the legacy
+        format.
+        """
+        # This is the pre-Django 3.1 encoded format.
+        legacy_encoded = (
+            'OWUzNTNmNWQxNTBjOWExZmM4MmQ3NzNhMDRmMjU4NmYwNDUyNGI2NDp7ImEgdGVzd'
+            'CBrZXkiOiJhIHRlc3QgdmFsdWUifQ=='
+        )
+        data = {'a test key': 'a test value'}
+        encoded = self.session.encode(data)
+        self.assertEqual(encoded, legacy_encoded)
+
+
+class DatabaseSessionTests(SessionTestsMixin, TestCase):
+    backend = DatabaseSession

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/sessions/backends/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 sessions_tests.test_legacy_session_encoding
cat coverage.cover
git checkout 6e9c5ee88fc948e05b4a7d9f82a8861ed2b0343d
git apply /root/pre_state.patch
