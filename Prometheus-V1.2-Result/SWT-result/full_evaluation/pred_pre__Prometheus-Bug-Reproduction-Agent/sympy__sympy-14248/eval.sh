#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9986b38181cdd556a3f3411e553864f11912244e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9986b38181cdd556a3f3411e553864f11912244e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/matrices/expressions/tests/test_printing.py b/sympy/matrices/expressions/tests/test_printing.py
new file mode 100644
index 0000000000..505a1a1964
--- /dev/null
+++ b/sympy/matrices/expressions/tests/test_printing.py
@@ -0,0 +1,27 @@
+import pytest
+from sympy import MatrixSymbol, pretty, latex
+
+def test_matrix_difference_printing():
+    """
+    Test printing the difference of MatrixSymbols.
+
+    This test case reproduces the issue where the difference of MatrixSymbols
+    is printed as a sum with a (-1) coefficient, rather than using a minus sign.
+    It checks the output of str, pretty, and latex printers.
+
+    Based on Stack Overflow post: https://stackoverflow.com/q/48826611
+    """
+    A = MatrixSymbol('A', 2, 2)
+    B = MatrixSymbol('B', 2, 2)
+    expr = A - A*B - B
+
+    # The current str output is "(-1)*B + (-1)*A*B + A"
+    # The correct output should respect term order and use minus signs.
+    assert str(expr) == "-B - A*B + A"
+
+    # The current pretty output is "-B + -A*B + A"
+    assert pretty(expr, use_unicode=False) == "-B - A*B + A"
+    assert pretty(expr, use_unicode=True) == u'-B - A⋅B + A'
+
+    # The current latex output is "-1 B + -1 A B + A"
+    assert latex(expr) == "-B - A B + A"

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/pretty/pretty\.py|sympy/printing/str\.py|sympy/printing/latex\.py)' bin/test -C --verbose sympy/matrices/expressions/tests/test_printing.p
cat coverage.cover
git checkout 9986b38181cdd556a3f3411e553864f11912244e
git apply /root/pre_state.patch
