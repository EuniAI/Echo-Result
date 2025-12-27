#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD de32fe83a2e4a20887972c69a0693b94eb25a88b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff de32fe83a2e4a20887972c69a0693b94eb25a88b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/handlers/test_append_slash.py b/tests/handlers/test_append_slash.py
new file mode 100644
index 0000000000..3717703269
--- /dev/null
+++ b/tests/handlers/test_append_slash.py
@@ -0,0 +1,34 @@
+from django.http import HttpResponse
+from django.test import TestCase, modify_settings, override_settings
+from django.urls import clear_url_caches, re_path
+
+# A minimal URLconf for the test case.
+# It defines a valid endpoint with a trailing slash.
+def empty_view(request):
+    return HttpResponse()
+
+urlpatterns = [
+    re_path(r'^slash/$', empty_view),
+]
+
+
+class HandlerAppendSlashTest(TestCase):
+    def setUp(self):
+        clear_url_caches()
+
+    def tearDown(self):
+        clear_url_caches()
+
+    @override_settings(APPEND_SLASH=True, ROOT_URLCONF=__name__)
+    @modify_settings(MIDDLEWARE={'remove': 'django.middleware.common.CommonMiddleware'})
+    def test_append_slash_with_script_name(self):
+        """
+        APPEND_SLASH redirection from a 404 handler should respect SCRIPT_NAME.
+
+        This test removes CommonMiddleware to ensure the redirect logic in the
+        404 handler is tested. In older Django versions, this logic was in
+        the handler and was buggy. CommonMiddleware can also perform this
+        redirect, potentially masking the bug in the handler.
+        """
+        response = self.client.get('/slash', SCRIPT_NAME='/prefix')
+        self.assertRedirects(response, '/prefix/slash/', status_code=301, target_status_code=404)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/sites\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 handlers.test_append_slash
cat coverage.cover
git checkout de32fe83a2e4a20887972c69a0693b94eb25a88b
git apply /root/pre_state.patch
