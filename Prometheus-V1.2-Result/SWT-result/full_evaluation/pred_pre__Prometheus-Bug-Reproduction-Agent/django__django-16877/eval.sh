#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 98f6ada0e2058d67d91fb6c16482411ec2ca0967 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 98f6ada0e2058d67d91fb6c16482411ec2ca0967
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/filter_tests/test_escapeseq.py b/tests/template_tests/filter_tests/test_escapeseq.py
new file mode 100644
index 0000000000..8476d787f5
--- /dev/null
+++ b/tests/template_tests/filter_tests/test_escapeseq.py
@@ -0,0 +1,18 @@
+from django.test import SimpleTestCase
+
+from ..utils import setup
+
+
+class EscapeseqTests(SimpleTestCase):
+    @setup(
+        {
+            "escapeseq01": (
+                "{% autoescape off %}"
+                "{{ a|escapeseq|join:',' }}"
+                "{% endautoescape %}"
+            )
+        }
+    )
+    def test_escapeseq01(self):
+        output = self.engine.render_to_string("escapeseq01", {"a": ["&", "<"]})
+        self.assertEqual(output, "&amp;,&lt;")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/defaultfilters\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.filter_tests.test_escapeseq
cat coverage.cover
git checkout 98f6ada0e2058d67d91fb6c16482411ec2ca0967
git apply /root/pre_state.patch
