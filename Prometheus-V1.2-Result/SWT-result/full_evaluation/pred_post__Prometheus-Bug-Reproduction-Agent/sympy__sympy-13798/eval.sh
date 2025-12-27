#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7121bdf1facdd90d05b6994b4c2e5b2865a4638a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7121bdf1facdd90d05b6994b4c2e5b2865a4638a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/latex.py b/sympy/printing/latex.py
--- a/sympy/printing/latex.py
+++ b/sympy/printing/latex.py
@@ -155,12 +155,23 @@ def __init__(self, settings=None):
             "dot": r" \cdot ",
             "times": r" \times "
         }
-
-        self._settings['mul_symbol_latex'] = \
-            mul_symbol_table[self._settings['mul_symbol']]
-
-        self._settings['mul_symbol_latex_numbers'] = \
-            mul_symbol_table[self._settings['mul_symbol'] or 'dot']
+        try:
+            self._settings['mul_symbol_latex'] = \
+                mul_symbol_table[self._settings['mul_symbol']]
+        except KeyError:
+            self._settings['mul_symbol_latex'] = \
+                self._settings['mul_symbol']
+        try:
+            self._settings['mul_symbol_latex_numbers'] = \
+                mul_symbol_table[self._settings['mul_symbol'] or 'dot']
+        except KeyError:
+            if (self._settings['mul_symbol'].strip() in
+                    ['', ' ', '\\', '\\,', '\\:', '\\;', '\\quad']):
+                self._settings['mul_symbol_latex_numbers'] = \
+                    mul_symbol_table['dot']
+            else:
+                self._settings['mul_symbol_latex_numbers'] = \
+                    self._settings['mul_symbol']
 
         self._delim_dict = {'(': ')', '[': ']'}
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_latex_mul_symbol.py b/sympy/printing/tests/test_latex_mul_symbol.py
new file mode 100644
index 0000000000..bd6b5204e7
--- /dev/null
+++ b/sympy/printing/tests/test_latex_mul_symbol.py
@@ -0,0 +1,10 @@
+import pytest
+from sympy import symbols
+from sympy.printing.latex import latex
+
+x, y = symbols('x y')
+
+
+def test_latex_custom_mul_symbol():
+    """Test that latex() accepts a custom string for mul_symbol."""
+    assert latex(3*x**2*y, mul_symbol=r'\,') == r'3 \, x^{2} \, y'

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/latex\.py)' bin/test -C --verbose sympy/printing/tests/test_latex_mul_symbol.p
cat coverage.cover
git checkout 7121bdf1facdd90d05b6994b4c2e5b2865a4638a
git apply /root/pre_state.patch
