#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b4777fdcef467b7132c055f8ac2c9a5059e6a145 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b4777fdcef467b7132c055f8ac2c9a5059e6a145
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/parsing/tests/test_latex_precedence.py b/sympy/parsing/tests/test_latex_precedence.py
new file mode 100644
index 0000000000..34877aebfc
--- /dev/null
+++ b/sympy/parsing/tests/test_latex_precedence.py
@@ -0,0 +1,24 @@
+from sympy.external import import_module
+from sympy.abc import a, b, c
+from sympy.parsing.latex import parse_latex
+
+# disable tests if antlr4-python*-runtime is not present
+antlr4 = import_module("antlr4")
+if not antlr4:
+    disabled = True
+
+
+def test_nested_fraction_precedence():
+    """
+    Test for issue of wrong precedence in nested fractions.
+
+    A fraction in the denominator of another fraction should be enclosed
+    in parentheses to maintain the correct order of operations. This test
+    checks that `parse_latex` correctly groups the denominator.
+    """
+    latex_expr = r"\frac{\frac{a^3+b}{c}}{\frac{1}{c^2}}"
+    # The buggy output is ((a**3 + b)/c)/1/(c**2), which evaluates to (a**3 + b)/c**3.
+    # The correct parsing is ((a**3 + b)/c)/(1/(c**2)), which evaluates to c*(a**3 + b).
+    expected_expr = ((a**3 + b) / c) / (1 / c**2)
+    parsed_expr = parse_latex(latex_expr)
+    assert parsed_expr == expected_expr

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/str\.py)' bin/test -C --verbose sympy/parsing/tests/test_latex_precedence.p
cat coverage.cover
git checkout b4777fdcef467b7132c055f8ac2c9a5059e6a145
git apply /root/pre_state.patch
