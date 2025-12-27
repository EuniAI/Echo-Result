#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e188d56ed1248dead58f3f8018c0e9a3f99193f7 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e188d56ed1248dead58f3f8018c0e9a3f99193f7
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_napoleon_numpy_docstring.py b/tests/test_ext_napoleon_numpy_docstring.py
new file mode 100644
index 000000000..1f9c6e384
--- /dev/null
+++ b/tests/test_ext_napoleon_numpy_docstring.py
@@ -0,0 +1,46 @@
+import pytest
+from unittest import TestCase
+from textwrap import dedent
+
+from sphinx.ext.napoleon import Config
+from sphinx.ext.napoleon.docstring import NumpyDocstring
+
+
+class BaseDocstringTest(TestCase):
+    pass
+
+
+class NumpyDocstringTest(BaseDocstringTest):
+    def test_multiple_parameters_on_one_line_with_optional(self):
+        """
+        Tests that 'optional' is correctly parsed for multiple parameters.
+
+        This test reproduces the bug where ', optional' is incorrectly parsed
+        as part of the description instead of the type. It asserts that the
+        generated output matches the ideal, correct output.
+
+        This test will FAIL if the bug is present, showing a diff between
+        the buggy output and the correct output. It will PASS once the bug
+        is fixed.
+        """
+        docstring = dedent('''\
+            A function with a multi-variable parameter line.
+
+            Parameters
+            ----------
+            x1, x2 : array_like, optional
+                Input arrays, description of `x1`, `x2`.
+            ''')
+
+        # This is the ideal, correct output for the single-line parameter style.
+        expected = dedent('''\
+            A function with a multi-variable parameter line.
+
+            :Parameters: **x1, x2** (*:class:`array_like`*, *optional*) -- Input arrays, description of `x1`, `x2`.
+            ''')
+
+        # The bug is apparent with napoleon_use_param=False.
+        config = Config(napoleon_use_param=False)
+        actual = str(NumpyDocstring(docstring, config))
+
+        self.assertEqual(expected.strip(), actual.strip())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/napoleon/docstring\.py)' -m tox -epy39 -v -- tests/test_ext_napoleon_numpy_docstring.py
cat coverage.cover
git checkout e188d56ed1248dead58f3f8018c0e9a3f99193f7
git apply /root/pre_state.patch
