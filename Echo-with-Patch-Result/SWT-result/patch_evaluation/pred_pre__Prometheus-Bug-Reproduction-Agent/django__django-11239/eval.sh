#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d87bd29c4f8dfcdf3f4a4eb8340e6770a2416fe3 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d87bd29c4f8dfcdf3f4a4eb8340e6770a2416fe3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/dbshell/test_postgresql_ssl.py b/tests/dbshell/test_postgresql_ssl.py
new file mode 100644
index 0000000000..5a4a8296e9
--- /dev/null
+++ b/tests/dbshell/test_postgresql_ssl.py
@@ -0,0 +1,53 @@
+import os
+import subprocess
+from unittest import mock
+
+from django.db.backends.postgresql.client import DatabaseClient
+from django.test import SimpleTestCase
+
+
+class PsqlDbshellCommandSslTestCase(SimpleTestCase):
+    def _get_subprocess_env(self, dbinfo):
+        """
+        Mock subprocess.run() and return the environment used to call it.
+        """
+        subprocess_env = None
+
+        def _mock_subprocess_run(*args, env=os.environ, **kwargs):
+            nonlocal subprocess_env
+            subprocess_env = env
+            return subprocess.CompletedProcess(list(*args), 0)
+
+        with mock.patch("subprocess.run", new=_mock_subprocess_run):
+            DatabaseClient.runshell_db(dbinfo)
+        return subprocess_env
+
+    def test_ssl_parameters_are_passed_to_psql_environment(self):
+        """
+        SSL options are passed to psql via environment variables.
+        """
+        dbinfo = {
+            "database": "dbname",
+            "user": "someuser",
+            "host": "somehost",
+            "port": "444",
+            "sslmode": "verify-ca",
+            "sslrootcert": "ca.crt",
+            "sslcert": "client_cert_chain.crt",
+            "sslkey": "client_key.key",
+        }
+        env = self._get_subprocess_env(dbinfo)
+        self.assertEqual(
+            {
+                "PGSSLMODE": env.get("PGSSLMODE"),
+                "PGSSLROOTCERT": env.get("PGSSLROOTCERT"),
+                "PGSSLCERT": env.get("PGSSLCERT"),
+                "PGSSLKEY": env.get("PGSSLKEY"),
+            },
+            {
+                "PGSSLMODE": "verify-ca",
+                "PGSSLROOTCERT": "ca.crt",
+                "PGSSLCERT": "client_cert_chain.crt",
+                "PGSSLKEY": "client_key.key",
+            },
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/postgresql/client\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 dbshell.test_postgresql_ssl
cat coverage.cover
git checkout d87bd29c4f8dfcdf3f4a4eb8340e6770a2416fe3
git apply /root/pre_state.patch
