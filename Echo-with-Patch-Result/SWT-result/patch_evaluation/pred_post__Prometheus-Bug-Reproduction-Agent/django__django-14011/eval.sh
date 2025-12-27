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
diff --git a/django/core/servers/basehttp.py b/django/core/servers/basehttp.py
--- a/django/core/servers/basehttp.py
+++ b/django/core/servers/basehttp.py
@@ -16,6 +16,7 @@
 from django.core.exceptions import ImproperlyConfigured
 from django.core.handlers.wsgi import LimitedStream
 from django.core.wsgi import get_wsgi_application
+from django.db import connections
 from django.utils.module_loading import import_string
 
 __all__ = ('WSGIServer', 'WSGIRequestHandler')
@@ -81,6 +82,28 @@ class ThreadedWSGIServer(socketserver.ThreadingMixIn, WSGIServer):
     """A threaded version of the WSGIServer"""
     daemon_threads = True
 
+    def __init__(self, *args, connections_override=None, **kwargs):
+        super().__init__(*args, **kwargs)
+        self.connections_override = connections_override
+
+    # socketserver.ThreadingMixIn.process_request() passes this method as
+    # the target to a new Thread object.
+    def process_request_thread(self, request, client_address):
+        if self.connections_override:
+            # Override this thread's database connections with the ones
+            # provided by the parent thread.
+            for alias, conn in self.connections_override.items():
+                connections[alias] = conn
+        super().process_request_thread(request, client_address)
+
+    def _close_connections(self):
+        # Used for mocking in tests.
+        connections.close_all()
+
+    def close_request(self, request):
+        self._close_connections()
+        super().close_request(request)
+
 
 class ServerHandler(simple_server.ServerHandler):
     http_version = '1.1'
diff --git a/django/db/backends/sqlite3/features.py b/django/db/backends/sqlite3/features.py
--- a/django/db/backends/sqlite3/features.py
+++ b/django/db/backends/sqlite3/features.py
@@ -83,6 +83,7 @@ def django_test_skips(self):
                 "the sqlite backend's close() method is a no-op when using an "
                 "in-memory database": {
                     'servers.test_liveserverthread.LiveServerThreadTest.test_closes_connections',
+                    'servers.tests.LiveServerTestCloseConnectionTest.test_closes_connections',
                 },
             })
         return skips

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_connection_handling.py b/tests/test_connection_handling.py
new file mode 100644
index 0000000000..5b61eb61ed
--- /dev/null
+++ b/tests/test_connection_handling.py
@@ -0,0 +1,71 @@
+from urllib.request import urlopen
+
+from django.db import connections, DEFAULT_DB_ALIAS
+from django.http import HttpResponse
+from django.test import LiveServerTestCase, override_settings
+from django.urls import path
+
+# A global dict to hold objects from the request-handler thread, preventing
+# them from being garbage-collected when the thread terminates.
+THREAD_STATE = {}
+
+
+def db_accessing_view(request):
+    """
+    A view that opens a database connection and then stores references to the
+    connection object and the connection handler in a global dict.
+    """
+    conn = connections[DEFAULT_DB_ALIAS]
+    conn.cursor()  # Ensure the connection is open.
+    # Store the connection wrapper from this thread.
+    THREAD_STATE["conn_obj"] = conn
+    # Store the connection handler from this thread to prevent its __del__
+    # method (which calls close_all()) from running when the thread exits.
+    # This is key to deterministically reproducing the bug.
+    THREAD_STATE["handler"] = connections
+    return HttpResponse("OK")
+
+
+# A minimal URLconf for the test case.
+urlpatterns = [
+    path("db_access/", db_accessing_view),
+]
+
+
+@override_settings(ROOT_URLCONF=__name__)
+class LiveServerThreadConnectionHandlingTest(LiveServerTestCase):
+    """
+    Test that connections opened by request handlers in the LiveServerThread
+    are closed immediately after the request, not just by garbage collection.
+    """
+
+    available_apps = []
+
+    def tearDown(self):
+        # Clean up global state after the test.
+        THREAD_STATE.clear()
+        super().tearDown()
+
+    def test_handler_thread_closes_connection(self):
+        """
+        The connection used in a request handler thread should be closed
+        after the request is complete.
+        """
+        self.assertNotIn("conn_obj", THREAD_STATE)
+
+        # Make a request to the view. urlopen blocks until the request is complete.
+        with urlopen(self.live_server_url + "/db_access/"):
+            pass
+
+        # The view should have stored the connection object.
+        self.assertIn("conn_obj", THREAD_STATE)
+        thread_conn = THREAD_STATE["conn_obj"]
+
+        # This is the core assertion.
+        # With the patch, the server wrapper calls `connections.close_all()` at
+        # the end of the request, which sets `thread_conn.connection` to None.
+        # Without the patch, this doesn't happen. Because we are holding a
+        # reference to the thread's connection handler, the connection is
+        # not closed by garbage collection, so `thread_conn.connection`
+        # remains a connection object.
+        self.assertIsNone(thread_conn.connection)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/servers/basehttp\.py|django/db/backends/sqlite3/features\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_connection_handling
cat coverage.cover
git checkout e4430f22c8e3d29ce5d9d0263fba57121938d06d
git apply /root/pre_state.patch
