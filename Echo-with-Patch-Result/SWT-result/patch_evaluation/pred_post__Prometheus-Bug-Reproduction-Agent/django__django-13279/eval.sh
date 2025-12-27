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
diff --git a/django/contrib/sessions/backends/base.py b/django/contrib/sessions/backends/base.py
--- a/django/contrib/sessions/backends/base.py
+++ b/django/contrib/sessions/backends/base.py
@@ -108,6 +108,9 @@ def _hash(self, value):
 
     def encode(self, session_dict):
         "Return the given session dictionary serialized and encoded as a string."
+        # RemovedInDjango40Warning: DEFAULT_HASHING_ALGORITHM will be removed.
+        if settings.DEFAULT_HASHING_ALGORITHM == 'sha1':
+            return self._legacy_encode(session_dict)
         return signing.dumps(
             session_dict, salt=self.key_salt, serializer=self.serializer,
             compress=True,
@@ -121,6 +124,12 @@ def decode(self, session_data):
         except Exception:
             return self._legacy_decode(session_data)
 
+    def _legacy_encode(self, session_dict):
+        # RemovedInDjango40Warning.
+        serialized = self.serializer().dumps(session_dict)
+        hash = self._hash(serialized)
+        return base64.b64encode(hash.encode() + b':' + serialized).decode('ascii')
+
     def _legacy_decode(self, session_data):
         # RemovedInDjango40Warning: pre-Django 3.1 format will be invalid.
         encoded_data = base64.b64decode(session_data.encode('ascii'))

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/sessions/test_sha1_encoding.py b/tests/sessions/test_sha1_encoding.py
new file mode 100644
index 0000000000..cedcaf7c3c
--- /dev/null
+++ b/tests/sessions/test_sha1_encoding.py
@@ -0,0 +1,31 @@
+import warnings
+
+from django.contrib.sessions.backends.db import SessionStore
+from django.test import TestCase, ignore_warnings
+from django.utils.deprecation import RemovedInDjango40Warning
+
+
+class SessionSha1EncodingTests(TestCase):
+    # The legacy encoded data and session data are from
+    # sessions_tests.tests.SessionTestsMixin.test_decode_legacy().
+    SESSION_DATA = {'a test key': 'a test value'}
+    LEGACY_ENCODED_DATA = (
+        'OWUzNTNmNWQxNTBjOWExZmM4MmQ3NzNhMDRmMjU4NmYwNDUyNGI2NDp7ImEgdGVzd'
+        'CBrZXkiOiJhIHRlc3QgdmFsdWUifQ=='
+    )
+
+    @ignore_warnings(category=RemovedInDjango40Warning)
+    def test_encode_legacy_format_with_sha1_setting(self):
+        """
+        When DEFAULT_HASHING_ALGORITHM is 'sha1', SessionBase.encode() should
+        use the legacy pre-3.1 format and issue a warning.
+        """
+        with self.settings(
+            DEFAULT_HASHING_ALGORITHM='sha1',
+            SECRET_KEY='django_tests_secret_key',
+        ):
+            session = SessionStore()
+            # The patched encode() method should issue a warning.
+            with self.assertWarns(RemovedInDjango40Warning):
+                encoded_data = session.encode(self.SESSION_DATA)
+            self.assertEqual(encoded_data, self.LEGACY_ENCODED_DATA)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/sessions/backends/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 sessions.test_sha1_encoding
cat coverage.cover
git checkout 6e9c5ee88fc948e05b4a7d9f82a8861ed2b0343d
git apply /root/pre_state.patch
