#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e39e727ded673e74016b5d3658d23cbe20234d11 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e39e727ded673e74016b5d3658d23cbe20234d11
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/asgi/test_asgi_middleware.py b/tests/asgi/test_asgi_middleware.py
new file mode 100644
index 0000000000..30d1a5ee47
--- /dev/null
+++ b/tests/asgi/test_asgi_middleware.py
@@ -0,0 +1,48 @@
+import sys
+from unittest import skipIf
+
+from django.http import HttpResponse
+from django.test import SimpleTestCase, override_settings
+from django.utils.deprecation import MiddlewareMixin
+
+# This dictionary is used to pass the response type from the middleware to the
+# test.
+response_info = {}
+
+
+class CaptureResponseTypeMiddleware(MiddlewareMixin):
+    """
+    Middleware that captures the type of the response object it receives in
+    its process_response() method.
+    """
+    def process_response(self, request, response):
+        response_info['type'] = response.__class__
+        return response
+
+
+@skipIf(sys.platform == 'win32' and (3, 8, 0) < sys.version_info < (3, 8, 1), 'https://bugs.python.org/issue38563')
+@override_settings(ROOT_URLCONF='asgi.urls')
+class ASGIMiddlewareTest(SimpleTestCase):
+    def setUp(self):
+        response_info.clear()
+
+    def tearDown(self):
+        response_info.clear()
+
+    @override_settings(
+        MIDDLEWARE=[
+            'asgi.test_asgi_middleware.CaptureResponseTypeMiddleware',
+            'django.middleware.security.SecurityMiddleware',
+            'django.contrib.sessions.middleware.SessionMiddleware',
+            'django.middleware.common.CommonMiddleware',
+            'django.contrib.auth.middleware.AuthenticationMiddleware',
+            'django.contrib.messages.middleware.MessageMiddleware',
+        ]
+    )
+    async def test_first_middleware_process_response_receives_response(self):
+        """
+        Under ASGI, the first middleware's process_response() should receive an
+        HttpResponse, not a coroutine.
+        """
+        await self.async_client.get('/')
+        self.assertTrue(issubclass(response_info['type'], HttpResponse))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/middleware/cache\.py|django/middleware/security\.py|django/contrib/sessions/middleware\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 asgi.test_asgi_middleware
cat coverage.cover
git checkout e39e727ded673e74016b5d3658d23cbe20234d11
git apply /root/pre_state.patch
