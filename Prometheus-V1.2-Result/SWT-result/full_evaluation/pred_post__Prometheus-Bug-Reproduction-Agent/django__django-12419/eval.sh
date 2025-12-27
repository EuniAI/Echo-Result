#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7fa1a93c6c8109010a6ff3f604fda83b604e0e97 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7fa1a93c6c8109010a6ff3f604fda83b604e0e97
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/conf/global_settings.py b/django/conf/global_settings.py
--- a/django/conf/global_settings.py
+++ b/django/conf/global_settings.py
@@ -637,6 +637,6 @@ def gettext_noop(s):
 SECURE_HSTS_PRELOAD = False
 SECURE_HSTS_SECONDS = 0
 SECURE_REDIRECT_EXEMPT = []
-SECURE_REFERRER_POLICY = None
+SECURE_REFERRER_POLICY = 'same-origin'
 SECURE_SSL_HOST = None
 SECURE_SSL_REDIRECT = False

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/middleware/test_security_2.py b/tests/middleware/test_security_2.py
new file mode 100644
index 0000000000..a85edfc680
--- /dev/null
+++ b/tests/middleware/test_security_2.py
@@ -0,0 +1,50 @@
+from django.http import HttpResponse
+from django.test import RequestFactory, SimpleTestCase
+from django.test.utils import override_settings
+
+
+class SecurityMiddlewareTest(SimpleTestCase):
+    @property
+    def middleware(self):
+        from django.middleware.security import SecurityMiddleware
+        return SecurityMiddleware()
+
+    @property
+    def secure_request_kwargs(self):
+        return {"wsgi.url_scheme": "https"}
+
+    def response(self, *args, headers=None, **kwargs):
+        response = HttpResponse(*args, **kwargs)
+        if headers:
+            for k, v in headers.items():
+                response[k] = v
+        return response
+
+    def process_response(self, *args, secure=False, request=None, **kwargs):
+        request_kwargs = {}
+        if secure:
+            request_kwargs.update(self.secure_request_kwargs)
+        if request is None:
+            request = self.request.get("/some/url", **request_kwargs)
+        ret = self.middleware.process_request(request)
+        if ret:
+            return ret
+        return self.middleware.process_response(
+            request, self.response(*args, **kwargs))
+
+    request = RequestFactory()
+
+    def process_request(self, method, *args, secure=False, **kwargs):
+        if secure:
+            kwargs.update(self.secure_request_kwargs)
+        req = getattr(self.request, method.lower())(*args, **kwargs)
+        return self.middleware.process_request(req)
+
+    def test_referrer_policy_default(self):
+        """
+        The default Referrer-Policy header is "same-origin".
+        """
+        # This test will fail if SECURE_REFERRER_POLICY defaults to None.
+        # It will pass when the default is changed to 'same-origin'.
+        response = self.process_response()
+        self.assertEqual(response.get('Referrer-Policy'), 'same-origin')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/conf/global_settings\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 middleware.test_security_2
cat coverage.cover
git checkout 7fa1a93c6c8109010a6ff3f604fda83b604e0e97
git apply /root/pre_state.patch
