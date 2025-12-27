#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 429d089d0a8fbd400e0c010708df4f0d16218970 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 429d089d0a8fbd400e0c010708df4f0d16218970
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_middleware_not_used_asgi.py b/tests/test_middleware_not_used_asgi.py
new file mode 100644
index 0000000000..64a031d6b0
--- /dev/null
+++ b/tests/test_middleware_not_used_asgi.py
@@ -0,0 +1,50 @@
+from django.core.exceptions import MiddlewareNotUsed
+from django.http import HttpResponse
+from django.test import SimpleTestCase, override_settings
+from django.urls import path
+
+
+class MiddlewareNotUsedSyncMiddleware:
+    """A sync-only middleware that raises MiddlewareNotUsed."""
+    sync_capable = True
+    async_capable = False
+
+    def __init__(self, get_response):
+        raise MiddlewareNotUsed()
+
+
+async def async_view(request):
+    return HttpResponse('OK')
+
+
+urlpatterns = [
+    path('async_view/', async_view),
+]
+
+
+@override_settings(ROOT_URLCONF=__name__)
+class MiddlewareNotUsedASGITest(SimpleTestCase):
+    @override_settings(
+        MIDDLEWARE=[
+            # This sync middleware is processed after the broken one because
+            # MIDDLEWARE is processed in reverse. On the unpatched code, it
+            # receives the poisoned handler, leading to a synchronous chain.
+            'django.middleware.common.CommonMiddleware',
+            # This middleware raises MiddlewareNotUsed and, due to the bug,
+            # poisons the middleware chain by replacing the async handler
+            # with a sync one.
+            f'{__name__}.MiddlewareNotUsedSyncMiddleware',
+        ]
+    )
+    async def test_middleware_not_used_in_asgi(self):
+        """
+        A middleware that raises MiddlewareNotUsed in an ASGI context should not
+        corrupt the middleware chain.
+        """
+        # The setup causes the `_middleware_chain` to become a synchronous
+        # function on unpatched Django. Awaiting it in an async context raises
+        # a TypeError. This test will fail with that TypeError before the fix
+        # and pass when the bug is fixed.
+        response = await self.async_client.get('/async_view/')
+        self.assertEqual(response.status_code, 200)
+        self.assertEqual(response.content, b'OK')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/handlers/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_middleware_not_used_asgi
cat coverage.cover
git checkout 429d089d0a8fbd400e0c010708df4f0d16218970
git apply /root/pre_state.patch
