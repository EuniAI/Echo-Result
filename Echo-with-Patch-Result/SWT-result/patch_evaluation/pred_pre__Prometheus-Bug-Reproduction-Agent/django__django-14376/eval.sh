#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d06c5b358149c02a62da8a5469264d05f29ac659 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d06c5b358149c02a62da8a5469264d05f29ac659
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/backends/mysql/test_connection_params.py b/tests/backends/mysql/test_connection_params.py
new file mode 100644
index 0000000000..3fd026a152
--- /dev/null
+++ b/tests/backends/mysql/test_connection_params.py
@@ -0,0 +1,47 @@
+import unittest
+
+from django.db import connection
+from django.db.backends.mysql.base import DatabaseWrapper
+from django.test import TestCase
+
+
+@unittest.skipUnless(connection.vendor == 'mysql', 'MySQL tests')
+class ConnectionParamsTests(TestCase):
+    def test_deprecated_db_param(self):
+        """
+        The 'db' connection parameter is deprecated in favor of 'database'.
+        """
+        settings_dict = connection.settings_dict.copy()
+        settings_dict['NAME'] = 'test_name'
+        wrapper = DatabaseWrapper(settings_dict)
+        params = wrapper.get_connection_params()
+        self.assertIn('database', params)
+        self.assertNotIn('db', params)
+
+    def test_deprecated_passwd_param(self):
+        """
+        The 'passwd' connection parameter is deprecated in favor of 'password'.
+        """
+        settings_dict = connection.settings_dict.copy()
+        settings_dict['PASSWORD'] = 'test_password'
+        wrapper = DatabaseWrapper(settings_dict)
+        params = wrapper.get_connection_params()
+        self.assertIn('password', params)
+        self.assertNotIn('passwd', params)
+
+    def test_options_db_and_passwd_deprecated(self):
+        """
+        'db' and 'passwd' in connection OPTIONS are deprecated in favor of
+        'database' and 'password'.
+        """
+        settings_dict = connection.settings_dict.copy()
+        settings_dict['OPTIONS'] = {
+            'db': 'test_db_from_options',
+            'passwd': 'test_password_from_options',
+        }
+        wrapper = DatabaseWrapper(settings_dict)
+        params = wrapper.get_connection_params()
+        self.assertIn('database', params)
+        self.assertIn('password', params)
+        self.assertNotIn('db', params)
+        self.assertNotIn('passwd', params)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/mysql/base\.py|django/db/backends/mysql/client\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 backends.mysql.test_connection_params
cat coverage.cover
git checkout d06c5b358149c02a62da8a5469264d05f29ac659
git apply /root/pre_state.patch
