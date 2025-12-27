#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD dd528cb2cefc0db8b91a7ff0a2bc87305b976597 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff dd528cb2cefc0db8b91a7ff0a2bc87305b976597
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/filter_tests/test_json_script_no_id.py b/tests/template_tests/filter_tests/test_json_script_no_id.py
new file mode 100644
index 0000000000..8b5058d2dd
--- /dev/null
+++ b/tests/template_tests/filter_tests/test_json_script_no_id.py
@@ -0,0 +1,20 @@
+from django.test import SimpleTestCase
+
+from ..utils import setup
+
+
+class JsonScriptTests(SimpleTestCase):
+
+    @setup({'json-tag-no-id': '{{ value|json_script }}'})
+    def test_no_id(self):
+        """
+        json_script should work without an element_id.
+        """
+        output = self.engine.render_to_string(
+            'json-tag-no-id',
+            {'value': {'a': 'b'}}
+        )
+        self.assertEqual(
+            output,
+            '<script type="application/json">{"a": "b"}</script>'
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/html\.py|django/template/defaultfilters\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.filter_tests.test_json_script_no_id
cat coverage.cover
git checkout dd528cb2cefc0db8b91a7ff0a2bc87305b976597
git apply /root/pre_state.patch
