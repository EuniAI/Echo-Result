#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e065b293878b1e3ea56655aa9d33e87576cd77ff >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e065b293878b1e3ea56655aa9d33e87576cd77ff
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_auth_backends.py b/tests/test_auth_backends.py
new file mode 100644
index 0000000000..cc7e1af991
--- /dev/null
+++ b/tests/test_auth_backends.py
@@ -0,0 +1,17 @@
+from django.contrib.auth import authenticate
+from django.test import TestCase
+
+
+class ModelBackendTest(TestCase):
+    def test_authenticate_no_credentials_no_query(self):
+        """
+        ModelBackend.authenticate() doesn't query the database if username or
+        password is None.
+        """
+        with self.subTest('username=None'):
+            with self.assertNumQueries(0):
+                self.assertIsNone(authenticate(username=None, password='password'))
+
+        with self.subTest('password=None'):
+            with self.assertNumQueries(0):
+                self.assertIsNone(authenticate(username='user', password=None))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/backends\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_auth_backends
cat coverage.cover
git checkout e065b293878b1e3ea56655aa9d33e87576cd77ff
git apply /root/pre_state.patch
