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
diff --git a/tests/template_tests/syntax_tests/test_simple_tag_keyword_only_arg.py b/tests/template_tests/syntax_tests/test_simple_tag_keyword_only_arg.py
new file mode 100644
index 0000000000..d7650c5e76
--- /dev/null
+++ b/tests/template_tests/syntax_tests/test_simple_tag_keyword_only_arg.py
@@ -0,0 +1,21 @@
+from django.template import Context, Engine, Library
+from django.test import SimpleTestCase
+
+
+class KeywordOnlySimpleTagTests(SimpleTestCase):
+    def test_keyword_only_arg_with_default(self):
+        """
+        A simple_tag with a keyword-only argument with a default value can be
+        called by providing that keyword argument.
+        """
+        lib = Library()
+
+        @lib.simple_tag
+        def hello(*, greeting='hello'):
+            return f'{greeting} world'
+
+        engine = Engine()
+        engine.template_libraries['custom'] = lib
+        template = engine.from_string("{% load custom %}{% hello greeting='hi' %}")
+        output = template.render(Context())
+        self.assertEqual(output, 'hi world')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/library\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.syntax_tests.test_simple_tag_keyword_only_arg
cat coverage.cover
git checkout 69331bb851c34f05bc77e9fc24020fe6908b9cd5
git apply /root/pre_state.patch
