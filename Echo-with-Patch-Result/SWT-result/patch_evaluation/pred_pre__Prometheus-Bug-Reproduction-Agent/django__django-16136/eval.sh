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
diff --git a/tests/test_async_method_not_allowed.py b/tests/test_async_method_not_allowed.py
new file mode 100644
index 0000000000..020a06bb52
--- /dev/null
+++ b/tests/test_async_method_not_allowed.py
@@ -0,0 +1,43 @@
+from django.http import HttpResponse
+from django.test import SimpleTestCase, override_settings
+from django.urls import path
+from django.views import View
+
+
+class AsyncPostPutView(View):
+    """
+    An async View that implements POST and PUT, but not GET.
+    """
+    http_method_names = ["post", "put", "options"]
+
+    async def post(self, request, *args, **kwargs):
+        return HttpResponse("ok")
+
+    async def put(self, request, *args, **kwargs):
+        return HttpResponse("ok")
+
+
+urlpatterns = [
+    path("async-post-put/", AsyncPostPutView.as_view()),
+]
+
+
+@override_settings(ROOT_URLCONF=__name__)
+class AsyncMethodNotAllowedTests(SimpleTestCase):
+    async def test_get_on_async_view_without_get(self):
+        """
+        A GET request to an async view that does not implement GET should
+        return a 405 Method Not Allowed response.
+
+        On the unpatched codebase, this test is expected to FAIL with a
+        `TypeError: object HttpResponseNotAllowed can't be used in 'await'
+        expression` because the synchronous response from http_method_not_allowed
+        is not awaited.
+
+        On the patched codebase, this test will PASS, as the response is
+        correctly wrapped in a coroutine and awaited, returning a 405 status.
+        """
+        response = await self.async_client.get("/async-post-put/")
+        self.assertEqual(response.status_code, 405)
+        # The Allow header should list the implemented methods.
+        self.assertEqual(response.headers["Allow"], "POST, PUT, OPTIONS")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/views/generic/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_async_method_not_allowed
cat coverage.cover
git checkout 19e6efa50b603af325e7f62058364f278596758f
git apply /root/pre_state.patch
