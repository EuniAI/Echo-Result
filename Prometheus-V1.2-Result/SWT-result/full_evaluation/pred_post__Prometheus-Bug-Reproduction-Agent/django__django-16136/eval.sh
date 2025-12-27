#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 19e6efa50b603af325e7f62058364f278596758f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 19e6efa50b603af325e7f62058364f278596758f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/views/generic/base.py b/django/views/generic/base.py
--- a/django/views/generic/base.py
+++ b/django/views/generic/base.py
@@ -148,7 +148,16 @@ def http_method_not_allowed(self, request, *args, **kwargs):
             request.path,
             extra={"status_code": 405, "request": request},
         )
-        return HttpResponseNotAllowed(self._allowed_methods())
+        response = HttpResponseNotAllowed(self._allowed_methods())
+
+        if self.view_is_async:
+
+            async def func():
+                return response
+
+            return func()
+        else:
+            return response
 
     def options(self, request, *args, **kwargs):
         """Handle responding to requests for the OPTIONS HTTP verb."""

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/generic_views/test_async.py b/tests/generic_views/test_async.py
new file mode 100644
index 0000000000..d849964220
--- /dev/null
+++ b/tests/generic_views/test_async.py
@@ -0,0 +1,29 @@
+from django.http import HttpResponse
+from django.test import AsyncRequestFactory, SimpleTestCase
+from django.views import View
+
+
+class AsyncPostOnlyView(View):
+    """
+    A view that only defines an async POST handler, used to demonstrate
+    the bug when a different method like GET is requested.
+    """
+
+    async def post(self, request, *args, **kwargs):
+        return HttpResponse("ok")
+
+
+class AsyncCBVMethodNotAllowedTests(SimpleTestCase):
+    async def test_get_on_async_post_only_view(self):
+        """
+        A GET request to a view with only an async post method should return a
+        405 response. The bug causes a TypeError because HttpResponseNotAllowed
+        is not awaited correctly.
+        """
+        factory = AsyncRequestFactory()
+        request = factory.get("/")
+        view = AsyncPostOnlyView.as_view()
+        # This await call will raise the TypeError described in the bug report.
+        # When the bug is fixed, it will return a valid response.
+        response = await view(request)
+        self.assertEqual(response.status_code, 405)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/views/generic/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 generic_views.test_async
cat coverage.cover
git checkout 19e6efa50b603af325e7f62058364f278596758f
git apply /root/pre_state.patch
