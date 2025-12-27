#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e4430f22c8e3d29ce5d9d0263fba57121938d06d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e4430f22c8e3d29ce5d9d0263fba57121938d06d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/servers/test_liveserver_connection.py b/tests/servers/test_liveserver_connection.py
new file mode 100644
index 0000000000..69a9c0e994
--- /dev/null
+++ b/tests/servers/test_liveserver_connection.py
@@ -0,0 +1,36 @@
+from django.db import DEFAULT_DB_ALIAS, connections
+from django.test import LiveServerTestCase, TransactionTestCase
+
+
+# Use TransactionTestCase instead of TestCase to run outside of a transaction,
+# otherwise closing the connection would implicitly rollback and not set the
+# connection to None.
+class LiveServerThreadConnectionClosingTest(TransactionTestCase):
+    available_apps = []
+
+    def _run_live_server_thread(self, connections_override=None):
+        thread = LiveServerTestCase._create_server_thread(connections_override)
+        thread.daemon = True
+        thread.start()
+        thread.is_ready.wait()
+        thread.terminate()
+
+    def test_threaded_server_closes_db_connections(self):
+        """
+        The ThreadedWSGIServer spawned by LiveServerThread should close its
+        database connections on termination.
+        """
+        db_conn = connections[DEFAULT_DB_ALIAS]
+        # Pass a connection to the thread to check that it's closed.
+        connections_override = {DEFAULT_DB_ALIAS: db_conn}
+        # Open a database connection.
+        db_conn.connect()
+        db_conn.inc_thread_sharing()
+        try:
+            self.assertIsNotNone(db_conn.connection)
+            self._run_live_server_thread(connections_override)
+            # The connection should be closed by the thread. This is the
+            # assertion that is expected to fail due to the bug.
+            self.assertIsNone(db_conn.connection)
+        finally:
+            db_conn.dec_thread_sharing()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/sqlite3/features\.py|django/core/servers/basehttp\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 servers.test_liveserver_connection
cat coverage.cover
git checkout e4430f22c8e3d29ce5d9d0263fba57121938d06d
git apply /root/pre_state.patch
