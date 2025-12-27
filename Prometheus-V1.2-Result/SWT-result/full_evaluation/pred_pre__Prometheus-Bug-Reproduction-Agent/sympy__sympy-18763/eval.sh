#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 70381f282f2d9d039da860e391fe51649df2779d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 70381f282f2d9d039da860e391fe51649df2779d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_latex_subs.py b/sympy/printing/tests/test_latex_subs.py
new file mode 100644
index 0000000000..3f091a53f7
--- /dev/null
+++ b/sympy/printing/tests/test_latex_subs.py
@@ -0,0 +1,11 @@
+from sympy import Subs
+from sympy.abc import x, y
+from sympy.printing.latex import latex
+
+
+def test_latex_subs_parenthesizing():
+    """
+    Test for incorrect parenthesizing of Subs.
+    """
+    expr = 3*Subs(-x + y, (x,), (1,))
+    assert latex(expr) == r'3 \left. \left(- x + y\right) \right|_{\substack{ x=1 }}'

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/latex\.py)' bin/test -C --verbose sympy/printing/tests/test_latex_subs.p
cat coverage.cover
git checkout 70381f282f2d9d039da860e391fe51649df2779d
git apply /root/pre_state.patch
