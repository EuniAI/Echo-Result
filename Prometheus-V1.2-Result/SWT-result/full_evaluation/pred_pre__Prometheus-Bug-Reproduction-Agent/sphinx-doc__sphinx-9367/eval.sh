#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6918e69600810a4664e53653d6ff0290c3c4a788 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6918e69600810a4664e53653d6ff0290c3c4a788
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_pycode_ast_regression.py b/tests/test_pycode_ast_regression.py
new file mode 100644
index 000000000..4016915ce
--- /dev/null
+++ b/tests/test_pycode_ast_regression.py
@@ -0,0 +1,16 @@
+import sys
+import pytest
+from sphinx.pycode import ast
+
+
+@pytest.mark.parametrize('source,expected', [
+    ("(1,)", "(1,)"),                           # Tuple (single element)
+])
+def test_unparse_single_element_tuple(source, expected):
+    """
+    Tests that unparsing a single-element tuple preserves the trailing comma.
+
+    This is a regression test for the issue where `(1,)` was rendered as `(1)`.
+    """
+    module = ast.parse(source)
+    assert ast.unparse(module.body[0].value, source) == expected

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/pycode/ast\.py)' -m tox -epy39 -v -- tests/test_pycode_ast_regression.py
cat coverage.cover
git checkout 6918e69600810a4664e53653d6ff0290c3c4a788
git apply /root/pre_state.patch
