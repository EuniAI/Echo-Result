#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 30379ea6e225e37833a764ac2da7b7fadf5fe374 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 30379ea6e225e37833a764ac2da7b7fadf5fe374
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_issue_13059.py b/sympy/core/tests/test_issue_13059.py
new file mode 100644
index 0000000000..4bc677ddb7
--- /dev/null
+++ b/sympy/core/tests/test_issue_13059.py
@@ -0,0 +1,21 @@
+from sympy import Mul, Max
+from sympy.abc import x, y
+
+
+def test_issue_13059():
+    """
+    Test for UnboundLocalError in evalf.
+
+    This was caused by the order of arguments in Mul containing a Max
+    object.
+
+    The call `Mul(Max(0, y), x, evaluate=False).evalf()` failed with
+    UnboundLocalError, while the same call with arguments reversed,
+    `Mul(x, Max(0, y), evaluate=False).evalf()`, did not.
+
+    The test will fail with UnboundLocalError if the bug is present.
+    When fixed, this test should pass.
+    """
+    expr = Mul(Max(0, y), x, evaluate=False)
+    result = expr.evalf()
+    assert result == Mul(x, Max(0, y))

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/evalf\.py)' bin/test -C --verbose sympy/core/tests/test_issue_13059.p
cat coverage.cover
git checkout 30379ea6e225e37833a764ac2da7b7fadf5fe374
git apply /root/pre_state.patch
