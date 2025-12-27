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
diff --git a/tests/dbshell/test_postgresql_client.py b/tests/dbshell/test_postgresql_client.py
new file mode 100644
index 0000000000..3a9b4b1701
--- /dev/null
+++ b/tests/dbshell/test_postgresql_client.py
@@ -0,0 +1,34 @@
+import os
+import signal
+from unittest import mock
+
+from django.db.backends.postgresql.client import DatabaseClient
+from django.test import SimpleTestCase
+
+
+class PostgreSqlDbshellCommandTestCase(SimpleTestCase):
+
+    @mock.patch('django.db.backends.postgresql.client.subprocess.run')
+    def test_password_in_env(self, mock_run):
+        """
+        PGPASSWORD is passed in the environment to subprocess.run.
+        """
+        dbinfo = {
+            'database': 'dbname',
+            'user': 'someuser',
+            'password': 'somepassword',
+            'host': 'somehost',
+            'port': '444',
+        }
+        DatabaseClient.runshell_db(dbinfo)
+        mock_run.assert_called_once()
+        args, kwargs = mock_run.call_args
+        self.assertEqual(
+            args[0],
+            ['psql', '-U', 'someuser', '-h', 'somehost', '-p', '444', 'dbname'],
+        )
+        self.assertIn('env', kwargs)
+        env = kwargs['env']
+        self.assertIn('PGPASSWORD', env)
+        self.assertEqual(env['PGPASSWORD'], 'somepassword')
+        self.assertNotIn('PGPASSFILE', env)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/postgresql/client\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 dbshell.test_postgresql_client
cat coverage.cover
git checkout ddb293685235fd09e932805771ae97f72e817181
git apply /root/pre_state.patch
