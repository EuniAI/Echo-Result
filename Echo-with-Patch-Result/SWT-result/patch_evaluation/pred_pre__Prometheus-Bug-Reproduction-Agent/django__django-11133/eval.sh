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
diff --git a/tests/test_httpresponse_memoryview.py b/tests/test_httpresponse_memoryview.py
new file mode 100644
index 0000000000..7371cf2932
--- /dev/null
+++ b/tests/test_httpresponse_memoryview.py
@@ -0,0 +1,11 @@
+from django.http import HttpResponse
+from django.test import SimpleTestCase
+
+
+class MemoryviewResponseTests(SimpleTestCase):
+    def test_memoryview_in_list_content(self):
+        """
+        HttpResponse should handle a memoryview object inside an iterable.
+        """
+        response = HttpResponse([memoryview(b"My Content")])
+        self.assertEqual(response.content, b"My Content")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/http/response\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_httpresponse_memoryview
cat coverage.cover
git checkout 879cc3da6249e920b8d54518a0ae06de835d7373
git apply /root/pre_state.patch
