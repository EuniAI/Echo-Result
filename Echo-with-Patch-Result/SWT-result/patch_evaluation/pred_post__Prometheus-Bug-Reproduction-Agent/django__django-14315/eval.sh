#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 187118203197801c6cb72dc8b06b714b23b6dd3d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 187118203197801c6cb72dc8b06b714b23b6dd3d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/backends/base/client.py b/django/db/backends/base/client.py
--- a/django/db/backends/base/client.py
+++ b/django/db/backends/base/client.py
@@ -21,6 +21,5 @@ def settings_to_cmd_args_env(cls, settings_dict, parameters):
 
     def runshell(self, parameters):
         args, env = self.settings_to_cmd_args_env(self.connection.settings_dict, parameters)
-        if env:
-            env = {**os.environ, **env}
+        env = {**os.environ, **env} if env else None
         subprocess.run(args, env=env, check=True)
diff --git a/django/db/backends/postgresql/client.py b/django/db/backends/postgresql/client.py
--- a/django/db/backends/postgresql/client.py
+++ b/django/db/backends/postgresql/client.py
@@ -51,7 +51,7 @@ def settings_to_cmd_args_env(cls, settings_dict, parameters):
             env['PGSSLKEY'] = str(sslkey)
         if passfile:
             env['PGPASSFILE'] = str(passfile)
-        return args, env
+        return args, (env or None)
 
     def runshell(self, parameters):
         sigint_handler = signal.getsignal(signal.SIGINT)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/backends/postgresql/test_runshell.py b/tests/backends/postgresql/test_runshell.py
new file mode 100644
index 0000000000..b172300e4b
--- /dev/null
+++ b/tests/backends/postgresql/test_runshell.py
@@ -0,0 +1,29 @@
+import os
+from unittest import mock
+
+from django.db.backends.base.base import BaseDatabaseWrapper
+from django.db.backends.postgresql.client import DatabaseClient
+from django.test import SimpleTestCase
+
+
+class PostgresClientRunshellTests(SimpleTestCase):
+    @mock.patch("django.db.backends.base.client.subprocess.run")
+    def test_runshell_inherits_os_environ(self, mock_run):
+        """
+        runshell() should inherit os.environ if no database-specific
+        environment variables are specified.
+        """
+        mock_connection = mock.MagicMock(spec=BaseDatabaseWrapper)
+        mock_connection.settings_dict = {
+            "NAME": "test_db",
+            # No other settings, so settings_to_cmd_args_env()
+            # returns an empty dict.
+        }
+        client = DatabaseClient(mock_connection)
+        client.runshell([])
+
+        mock_run.assert_called_once()
+        _, kwargs = mock_run.call_args
+        # env=None means that the subprocess inherits the environment.
+        # An empty dict means it gets an empty environment.
+        self.assertIsNone(kwargs.get("env"))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/postgresql/client\.py|django/db/backends/base/client\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 backends.postgresql.test_runshell
cat coverage.cover
git checkout 187118203197801c6cb72dc8b06b714b23b6dd3d
git apply /root/pre_state.patch
