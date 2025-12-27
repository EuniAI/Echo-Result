#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 69331bb851c34f05bc77e9fc24020fe6908b9cd5 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 69331bb851c34f05bc77e9fc24020fe6908b9cd5
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/test_keyword_only_arg_simple_tag.py b/tests/template_tests/test_keyword_only_arg_simple_tag.py
new file mode 100644
index 0000000000..55b5d3d754
--- /dev/null
+++ b/tests/template_tests/test_keyword_only_arg_simple_tag.py
@@ -0,0 +1,48 @@
+import sys
+from types import ModuleType
+
+from django.template import Context, Engine, Library
+from django.test import SimpleTestCase
+
+
+# Set up a fake module for the custom template tags to make it importable by the engine.
+templatetags_module = ModuleType("keyword_only_tags_lib")
+sys.modules[templatetags_module.__name__] = templatetags_module
+register = Library()
+templatetags_module.register = register
+
+
+@register.simple_tag
+def hello(*, greeting="hello"):
+    """A simple tag with a keyword-only argument with a default value."""
+    return f"{greeting} world"
+
+
+class KeywordOnlyArgSimpleTagTests(SimpleTestCase):
+    """
+    Tests for simple_tag with keyword-only arguments.
+    """
+
+    libraries = {"keyword_only_tags": "keyword_only_tags_lib"}
+
+    @classmethod
+    def setUpClass(cls):
+        cls.engine = Engine(libraries=cls.libraries)
+        super().setUpClass()
+
+    @classmethod
+    def tearDownClass(cls):
+        # Clean up the fake module to avoid side effects in other tests.
+        del sys.modules["keyword_only_tags_lib"]
+        super().tearDownClass()
+
+    def test_keyword_only_arg_with_default_is_allowed(self):
+        """
+        A simple_tag with a keyword-only argument with a default value
+        should render correctly when the argument is provided.
+        """
+        template = self.engine.from_string(
+            "{% load keyword_only_tags %}{% hello greeting='hi' %}"
+        )
+        output = template.render(Context())
+        self.assertEqual(output, "hi world")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/library\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.test_keyword_only_arg_simple_tag
cat coverage.cover
git checkout 69331bb851c34f05bc77e9fc24020fe6908b9cd5
git apply /root/pre_state.patch
