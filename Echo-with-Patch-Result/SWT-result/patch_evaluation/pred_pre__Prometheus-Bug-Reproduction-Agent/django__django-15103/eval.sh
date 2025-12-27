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
diff --git a/tests/test_json_script.py b/tests/test_json_script.py
new file mode 100644
index 0000000000..e76ae8f42e
--- /dev/null
+++ b/tests/test_json_script.py
@@ -0,0 +1,17 @@
+from django.template import Context, Template
+from django.test import SimpleTestCase
+
+
+class JsonScriptTests(SimpleTestCase):
+    def test_json_script_without_element_id(self):
+        """
+        The json_script filter can be used without an element_id.
+        """
+        value = {'hello': 'world'}
+        template = Template('{{ value|json_script }}')
+        context = Context({'value': value})
+        rendered = template.render(context)
+        self.assertEqual(
+            rendered,
+            '<script type="application/json">{"hello": "world"}</script>',
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/html\.py|django/template/defaultfilters\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_json_script
cat coverage.cover
git checkout dd528cb2cefc0db8b91a7ff0a2bc87305b976597
git apply /root/pre_state.patch
