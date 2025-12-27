#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9ef28fba5b4d6d0168237c9c005a550e6dc27d81 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9ef28fba5b4d6d0168237c9c005a550e6dc27d81
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/mathematica.py b/sympy/printing/mathematica.py
--- a/sympy/printing/mathematica.py
+++ b/sympy/printing/mathematica.py
@@ -31,7 +31,8 @@
     "asech": [(lambda x: True, "ArcSech")],
     "acsch": [(lambda x: True, "ArcCsch")],
     "conjugate": [(lambda x: True, "Conjugate")],
-
+    "Max": [(lambda *x: True, "Max")],
+    "Min": [(lambda *x: True, "Min")],
 }
 
 
@@ -101,6 +102,8 @@ def _print_Function(self, expr):
                     return "%s[%s]" % (mfunc, self.stringify(expr.args, ", "))
         return expr.func.__name__ + "[%s]" % self.stringify(expr.args, ", ")
 
+    _print_MinMaxBase = _print_Function
+
     def _print_Integral(self, expr):
         if len(expr.variables) == 1 and not expr.limits[0][1:]:
             args = [expr.args[0], expr.variables[0]]

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_mathematica_2.py b/sympy/printing/tests/test_mathematica_2.py
new file mode 100644
index 0000000000..3a868ff0ff
--- /dev/null
+++ b/sympy/printing/tests/test_mathematica_2.py
@@ -0,0 +1,8 @@
+from sympy.core import symbols
+from sympy.functions import Max
+from sympy import mathematica_code as mcode
+
+
+def test_Max():
+    x = symbols('x')
+    assert mcode(Max(x, 2)) == 'Max[x, 2]'

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/mathematica\.py)' bin/test -C --verbose sympy/printing/tests/test_mathematica_2.p
cat coverage.cover
git checkout 9ef28fba5b4d6d0168237c9c005a550e6dc27d81
git apply /root/pre_state.patch
