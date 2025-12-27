#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 246eb4836a6fb967880f838aa0d22ecfdca8b6f1 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 246eb4836a6fb967880f838aa0d22ecfdca8b6f1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/servers/test_runserver_head.py b/tests/servers/test_runserver_head.py
new file mode 100644
index 0000000000..acb83287a8
--- /dev/null
+++ b/tests/servers/test_runserver_head.py
@@ -0,0 +1,48 @@
+import os
+import socket
+
+from django.test import LiveServerTestCase, override_settings
+
+TEST_ROOT = os.path.dirname(__file__)
+TEST_SETTINGS = {
+    "MEDIA_URL": "media/",
+    "MEDIA_ROOT": os.path.join(TEST_ROOT, "media"),
+    "STATIC_URL": "static/",
+    "STATIC_ROOT": os.path.join(TEST_ROOT, "static"),
+}
+
+
+@override_settings(ROOT_URLCONF="servers.urls", **TEST_SETTINGS)
+class LiveServerViews(LiveServerTestCase):
+    available_apps = [
+        "servers",
+        "django.contrib.auth",
+        "django.contrib.contenttypes",
+        "django.contrib.sessions",
+    ]
+
+    def test_head_request_no_body(self):
+        """
+        runserver must not send a message body on HTTP HEAD requests. This is
+        tested at the socket level to bypass client-side body stripping.
+        """
+        host, port = self.server_thread.host, self.server_thread.port
+        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
+            s.connect((host, port))
+            request = (
+                b"HEAD /example_view/ HTTP/1.1\r\n"
+                b"Host: %s:%d\r\n"
+                b"Connection: close\r\n"
+                b"\r\n"
+            ) % (host.encode(), port)
+            s.sendall(request)
+
+            response_data = b""
+            while True:
+                chunk = s.recv(4096)
+                if not chunk:
+                    break
+                response_data += chunk
+
+        headers, _, body = response_data.partition(b"\r\n\r\n")
+        self.assertEqual(body, b"")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/servers/basehttp\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 servers.test_runserver_head
cat coverage.cover
git checkout 246eb4836a6fb967880f838aa0d22ecfdca8b6f1
git apply /root/pre_state.patch
