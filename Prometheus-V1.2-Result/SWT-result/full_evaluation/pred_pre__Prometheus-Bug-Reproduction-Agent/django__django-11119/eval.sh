#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d4df5e1b0b1c643fe0fc521add0236764ec8e92a >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d4df5e1b0b1c643fe0fc521add0236764ec8e92a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/test_render_to_string_autoescape.py b/tests/template_tests/test_render_to_string_autoescape.py
new file mode 100644
index 0000000000..490e205e70
--- /dev/null
+++ b/tests/template_tests/test_render_to_string_autoescape.py
@@ -0,0 +1,15 @@
+from django.template.engine import Engine
+from django.test import SimpleTestCase
+
+
+class EngineRenderToStringAutoescapeTests(SimpleTestCase):
+
+    def test_render_to_string_honors_autoescape_off(self):
+        """
+        Engine.render_to_string() should honor autoescape=False.
+        """
+        templates = {'test.html': 'Hello, {{ name }}'}
+        loaders = [['django.template.loaders.locmem.Loader', templates]]
+        engine = Engine(loaders=loaders, autoescape=False)
+        rendered = engine.render_to_string('test.html', {'name': 'Bob & Jim'})
+        self.assertEqual(rendered, 'Hello, Bob & Jim')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/engine\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.test_render_to_string_autoescape
cat coverage.cover
git checkout d4df5e1b0b1c643fe0fc521add0236764ec8e92a
git apply /root/pre_state.patch
