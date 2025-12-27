#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b4817d20b9e55df30be0b1b2ca8c8bb6d61aab07 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b4817d20b9e55df30be0b1b2ca8c8bb6d61aab07
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/dbshell/test_psql_args_order.py b/tests/dbshell/test_psql_args_order.py
new file mode 100644
index 0000000000..05704077f6
--- /dev/null
+++ b/tests/dbshell/test_psql_args_order.py
@@ -0,0 +1,19 @@
+from django.db.backends.postgresql.client import DatabaseClient
+from django.test import SimpleTestCase
+
+
+class PostgreSqlDbshellCommandTestCase(SimpleTestCase):
+    def settings_to_cmd_args_env(self, settings_dict, parameters=None):
+        if parameters is None:
+            parameters = []
+        return DatabaseClient.settings_to_cmd_args_env(settings_dict, parameters)
+
+    def test_additional_parameters_before_dbname(self):
+        """
+        Additional parameters are passed before the database name, which is what
+        psql expects.
+        """
+        settings = {"NAME": "somedbname"}
+        parameters = ["-c", "select * from some_table;"]
+        args, _ = self.settings_to_cmd_args_env(settings, parameters)
+        self.assertEqual(args[-1], "somedbname")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/postgresql/client\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 dbshell.test_psql_args_order
cat coverage.cover
git checkout b4817d20b9e55df30be0b1b2ca8c8bb6d61aab07
git apply /root/pre_state.patch
