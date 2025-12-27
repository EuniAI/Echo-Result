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
diff --git a/tests/backends/postgresql/test_client.py b/tests/backends/postgresql/test_client.py
new file mode 100644
index 0000000000..2fb2566c6f
--- /dev/null
+++ b/tests/backends/postgresql/test_client.py
@@ -0,0 +1,127 @@
+import os
+import signal
+import subprocess
+from unittest import mock
+
+from django.db.backends.postgresql.client import DatabaseClient
+from django.test import SimpleTestCase
+
+
+class PostgreSqlDbshellCommandTestCase(SimpleTestCase):
+
+    def _run_it(self, dbinfo):
+        """
+        That function invokes the runshell command, while mocking
+        subprocess.run(). It returns a 2-tuple with:
+        - The command line list
+        - The the value of the PGPASSWORD environment variable, or None.
+        """
+        def _mock_subprocess_run(*args, env=os.environ, **kwargs):
+            self.subprocess_args = list(*args)
+            self.pgpassword = env.get('PGPASSWORD')
+            return subprocess.CompletedProcess(self.subprocess_args, 0)
+        with mock.patch('subprocess.run', new=_mock_subprocess_run):
+            DatabaseClient.runshell_db(dbinfo)
+        return self.subprocess_args, self.pgpassword
+
+    def test_basic(self):
+        self.assertEqual(
+            self._run_it({
+                'database': 'dbname',
+                'user': 'someuser',
+                'password': 'somepassword',
+                'host': 'somehost',
+                'port': '444',
+            }), (
+                ['psql', '-U', 'someuser', '-h', 'somehost', '-p', '444', 'dbname'],
+                'somepassword',
+            )
+        )
+
+    def test_nopass(self):
+        self.assertEqual(
+            self._run_it({
+                'database': 'dbname',
+                'user': 'someuser',
+                'host': 'somehost',
+                'port': '444',
+            }), (
+                ['psql', '-U', 'someuser', '-h', 'somehost', '-p', '444', 'dbname'],
+                None,
+            )
+        )
+
+    def test_column(self):
+        self.assertEqual(
+            self._run_it({
+                'database': 'dbname',
+                'user': 'some:user',
+                'password': 'some:password',
+                'host': '::1',
+                'port': '444',
+            }), (
+                ['psql', '-U', 'some:user', '-h', '::1', '-p', '444', 'dbname'],
+                'some:password',
+            )
+        )
+
+    def test_accent(self):
+        username = 'rôle'
+        password = 'sésame'
+        self.assertEqual(
+            self._run_it({
+                'database': 'dbname',
+                'user': username,
+                'password': password,
+                'host': 'somehost',
+                'port': '444',
+            }), (
+                ['psql', '-U', username, '-h', 'somehost', '-p', '444', 'dbname'],
+                password,
+            )
+        )
+
+    def test_sigint_handler(self):
+        """SIGINT is ignored in Python and passed to psql to abort quries."""
+        def _mock_subprocess_run(*args, **kwargs):
+            handler = signal.getsignal(signal.SIGINT)
+            self.assertEqual(handler, signal.SIG_IGN)
+
+        sigint_handler = signal.getsignal(signal.SIGINT)
+        # The default handler isn't SIG_IGN.
+        self.assertNotEqual(sigint_handler, signal.SIG_IGN)
+        with mock.patch('subprocess.run', new=_mock_subprocess_run):
+            DatabaseClient.runshell_db({})
+        # dbshell restores the original handler.
+        self.assertEqual(sigint_handler, signal.getsignal(signal.SIGINT))
+
+    def test_ssl_client_certificate_options(self):
+        """
+        Client certificate SSL options are passed to psql as environment
+        variables.
+        """
+        dbinfo = {
+            'database': 'dbname',
+            'user': 'someuser',
+            'host': 'somehost',
+            'port': '444',
+            'password': '',
+            'options': {
+                'sslmode': 'verify-ca',
+                'sslrootcert': 'ca.crt',
+                'sslcert': 'client.crt',
+                'sslkey': 'client.key',
+            },
+        }
+        run_env = None
+
+        def _mock_subprocess_run(*args, env=os.environ, **kwargs):
+            nonlocal run_env
+            run_env = env
+            return subprocess.CompletedProcess(list(*args), 0)
+
+        with mock.patch('subprocess.run', new=_mock_subprocess_run):
+            DatabaseClient.runshell_db(dbinfo)
+
+        self.assertEqual(run_env.get('PGSSLCERT'), 'client.crt')
+        self.assertEqual(run_env.get('PGSSLKEY'), 'client.key')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/postgresql/client\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 backends.postgresql.test_client
cat coverage.cover
git checkout d87bd29c4f8dfcdf3f4a4eb8340e6770a2416fe3
git apply /root/pre_state.patch
