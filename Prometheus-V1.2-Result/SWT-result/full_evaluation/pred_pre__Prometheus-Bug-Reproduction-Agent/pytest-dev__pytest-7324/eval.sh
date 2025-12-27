#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 19ad5889353c7f5f2b65cc2acd346b7a9e95dfcd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 19ad5889353c7f5f2b65cc2acd346b7a9e95dfcd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_mark_expression_compile_false.py b/testing/test_mark_expression_compile_false.py
new file mode 100644
index 000000000..d095a8af3
--- /dev/null
+++ b/testing/test_mark_expression_compile_false.py
@@ -0,0 +1,22 @@
+import pytest
+from _pytest.mark.expression import Expression
+
+
+def test_compile_false_string_does_not_crash_or_raise():
+    """
+    Regression test for a crash on debug builds of Python 3.8+
+    and a ValueError on release builds.
+
+    `Expression.compile("False")` should not crash or raise, as "False"
+    should be treated as a valid identifier.
+    """
+    try:
+        expr = Expression.compile("False")
+        # To confirm it is treated as a valid identifier, we evaluate it.
+        # The matcher function will return True if it receives the "False" identifier.
+        assert expr.evaluate(lambda ident: ident == "False") is True
+    except ValueError:
+        pytest.fail(
+            "Expression.compile('False') raised ValueError, but it should be "
+            "treated as a valid identifier and not raise."
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/mark/expression\.py)' -m pytest -rA testing/test_mark_expression_compile_false.py
cat coverage.cover
git checkout 19ad5889353c7f5f2b65cc2acd346b7a9e95dfcd
git apply /root/pre_state.patch
