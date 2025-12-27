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
diff --git a/tests/test_escapeseq.py b/tests/test_escapeseq.py
new file mode 100644
index 0000000000..49cde13755
--- /dev/null
+++ b/tests/test_escapeseq.py
@@ -0,0 +1,16 @@
+from django.test import SimpleTestCase
+from django.template import Context, Engine
+
+
+class EscapeseqTests(SimpleTestCase):
+    def test_escapeseq_with_autoescape_off(self):
+        """
+        The escapeseq filter escapes each item in a sequence. This is
+        particularly useful with autoescape off, for example, before joining.
+        """
+        engine = Engine()
+        template = engine.from_string(
+            '{% autoescape off %}{{ a|escapeseq|join:"," }}{% endautoescape %}'
+        )
+        output = template.render(Context({"a": ["<", ">", "'", '"', "&"]}))
+        self.assertEqual(output, "&lt;,&gt;,&#x27;,&quot;,&amp;")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/defaultfilters\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_escapeseq
cat coverage.cover
git checkout 98f6ada0e2058d67d91fb6c16482411ec2ca0967
git apply /root/pre_state.patch
