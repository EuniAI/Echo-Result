#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6599608c4d0befdcb820ddccce55f183f247ae4f >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6599608c4d0befdcb820ddccce55f183f247ae4f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/handlers/test_debug_view.py b/tests/handlers/test_debug_view.py
new file mode 100644
index 0000000000..96ccf13e3a
--- /dev/null
+++ b/tests/handlers/test_debug_view.py
@@ -0,0 +1,39 @@
+from django.test import SimpleTestCase, override_settings
+from django.urls import path
+from django.views import View
+
+
+# View from the issue description that raises the chained exception.
+class TestView(View):
+    def get(self, request, *args, **kwargs):
+        try:
+            raise RuntimeError('my error')
+        except Exception as exc:
+            # This creates an exception where the context (RuntimeError)
+            # should be suppressed from the traceback.
+            raise ValueError('my new error') from None
+
+
+# Minimal URLconf for the test case.
+urlpatterns = [
+    path('suppressed_exception/', TestView.as_view()),
+]
+
+
+@override_settings(ROOT_URLCONF=__name__, DEBUG=True)
+class DebugViewTests(SimpleTestCase):
+    def test_suppress_context(self):
+        """
+        The debug error view should not show the chained exception if
+        __suppress_context__ is True (PEP 415).
+        """
+        # Disable the client's default behavior of re-raising exceptions.
+        # This allows us to inspect the content of the debug 500 response.
+        self.client.raise_request_exception = False
+        
+        response = self.client.get('/suppressed_exception/')
+        
+        # This assertion now fails as intended because the bug causes
+        # "RuntimeError" to be present in the traceback. Once the bug is
+        # fixed, this assertion will pass.
+        self.assertNotContains(response, 'RuntimeError', status_code=500)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/views/debug\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 handlers.test_debug_view
cat coverage.cover
git checkout 6599608c4d0befdcb820ddccce55f183f247ae4f
git apply /root/pre_state.patch
