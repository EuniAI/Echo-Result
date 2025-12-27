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
diff --git a/tests/backends/mysql/test_connections.py b/tests/backends/mysql/test_connections.py
new file mode 100644
index 0000000000..6af0fc7393
--- /dev/null
+++ b/tests/backends/mysql/test_connections.py
@@ -0,0 +1,31 @@
+import unittest
+from unittest.mock import patch
+
+from django.db import connection
+from django.db.backends.mysql.base import DatabaseWrapper
+from django.test import TestCase
+
+
+@unittest.skipUnless(connection.vendor == 'mysql', 'MySQL tests')
+class ConnectionTests(TestCase):
+    @patch('django.db.backends.mysql.base.Database.connect')
+    def test_deprecated_kwargs(self, mock_connect):
+        """
+        'db' and 'passwd' connection arguments are deprecated in favor of
+        'database' and 'password'.
+        """
+        settings_dict = {
+            'NAME': 'somedb',
+            'USER': 'someuser',
+            'PASSWORD': 'somepassword',
+            'HOST': 'somehost',
+            'PORT': 3306,
+            'OPTIONS': {},
+        }
+        wrapper = DatabaseWrapper(settings_dict)
+        wrapper.get_new_connection(wrapper.get_connection_params())
+        _, kwargs = mock_connect.call_args
+        self.assertNotIn('db', kwargs)
+        self.assertNotIn('passwd', kwargs)
+        self.assertEqual(kwargs['database'], 'somedb')
+        self.assertEqual(kwargs['password'], 'somepassword')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/mysql/client\.py|django/db/backends/mysql/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 backends.mysql.test_connections
cat coverage.cover
git checkout d06c5b358149c02a62da8a5469264d05f29ac659
git apply /root/pre_state.patch
