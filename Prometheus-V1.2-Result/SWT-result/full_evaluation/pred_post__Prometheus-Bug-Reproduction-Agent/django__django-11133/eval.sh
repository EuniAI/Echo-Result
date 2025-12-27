#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 879cc3da6249e920b8d54518a0ae06de835d7373 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 879cc3da6249e920b8d54518a0ae06de835d7373
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/http/response.py b/django/http/response.py
--- a/django/http/response.py
+++ b/django/http/response.py
@@ -229,7 +229,7 @@ def make_bytes(self, value):
         # Handle string types -- we can't rely on force_bytes here because:
         # - Python attempts str conversion first
         # - when self._charset != 'utf-8' it re-encodes the content
-        if isinstance(value, bytes):
+        if isinstance(value, (bytes, memoryview)):
             return bytes(value)
         if isinstance(value, str):
             return bytes(value.encode(self.charset))

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/responses/test_memoryview_content.py b/tests/responses/test_memoryview_content.py
new file mode 100644
index 0000000000..f90c52dd8a
--- /dev/null
+++ b/tests/responses/test_memoryview_content.py
@@ -0,0 +1,12 @@
+from django.http import HttpResponse
+from django.test import SimpleTestCase
+
+
+class HttpResponseTests(SimpleTestCase):
+
+    def test_memoryview_content(self):
+        """
+        HttpResponse should handle memoryview objects as content.
+        """
+        response = HttpResponse(memoryview(b'My Content'))
+        self.assertEqual(response.content, b'My Content')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/http/response\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 responses.test_memoryview_content
cat coverage.cover
git checkout 879cc3da6249e920b8d54518a0ae06de835d7373
git apply /root/pre_state.patch
