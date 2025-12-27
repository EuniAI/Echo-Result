#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ddb293685235fd09e932805771ae97f72e817181 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ddb293685235fd09e932805771ae97f72e817181
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/backends/postgresql/tests/test_client.py b/django/db/backends/postgresql/tests/test_client.py
new file mode 100644
index 0000000000..1d10ddd5e3
--- /dev/null
+++ b/django/db/backends/postgresql/tests/test_client.py
@@ -0,0 +1,27 @@
+import os
+import subprocess
+from unittest import mock, TestCase
+
+# Import only the client module to avoid loading the entire PostgreSQL backend
+from django.db.backends.postgresql.client import DatabaseClient
+
+
+class PostgreSqlClientTestCase(TestCase):
+    @mock.patch('django.db.backends.postgresql.client.subprocess.run')
+    @mock.patch('django.db.backends.postgresql.client.subprocess.check_call')
+    def test_runshell_db_uses_subprocess_run(self, mock_check_call, mock_run):
+        """
+        Test that runshell_db uses subprocess.run when a password is provided.
+        """
+        dbinfo = {
+            'database': 'testdb',
+            'user': 'testuser',
+            'password': 'testpass',
+            'host': 'testhost',
+            'port': '5432',
+        }
+        DatabaseClient.runshell_db(dbinfo)
+
+        # On the old code, subprocess.check_call is used, so this assertion fails.
+        # On the new code, subprocess.run is used, and this assertion passes.
+        mock_run.assert_called_once()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/postgresql/client\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 django.db.backends.postgresql.tests.test_client
cat coverage.cover
git checkout ddb293685235fd09e932805771ae97f72e817181
git apply /root/pre_state.patch
