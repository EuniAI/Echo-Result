#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD de446c6d85f633271dfec1452f6f28ea783e293f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff de446c6d85f633271dfec1452f6f28ea783e293f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/secondquant.py b/sympy/physics/secondquant.py
--- a/sympy/physics/secondquant.py
+++ b/sympy/physics/secondquant.py
@@ -218,7 +218,7 @@ def _sortkey(cls, index):
             return (12, label, h)
 
     def _latex(self, printer):
-        return "%s^{%s}_{%s}" % (
+        return "{%s^{%s}_{%s}}" % (
             self.symbol,
             "".join([ i.name for i in self.args[1]]),
             "".join([ i.name for i in self.args[2]])
@@ -478,7 +478,7 @@ def __repr__(self):
         return "CreateBoson(%s)" % self.state
 
     def _latex(self, printer):
-        return "b^\\dagger_{%s}" % self.state.name
+        return "{b^\\dagger_{%s}}" % self.state.name
 
 B = AnnihilateBoson
 Bd = CreateBoson
@@ -939,7 +939,7 @@ def __repr__(self):
         return "CreateFermion(%s)" % self.state
 
     def _latex(self, printer):
-        return "a^\\dagger_{%s}" % self.state.name
+        return "{a^\\dagger_{%s}}" % self.state.name
 
 Fd = CreateFermion
 F = AnnihilateFermion

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/printing/tests/test_latex_double_superscript.py b/sympy/printing/tests/test_latex_double_superscript.py
new file mode 100644
index 0000000000..4a82d8ccc8
--- /dev/null
+++ b/sympy/printing/tests/test_latex_double_superscript.py
@@ -0,0 +1,19 @@
+from sympy.physics.secondquant import (
+    B, Bd, Commutator
+)
+from sympy import (
+    Symbol
+)
+from sympy.printing.latex import latex
+
+
+def test_latex_double_superscript():
+    """
+    Test for latex printing of expressions containing double superscripts.
+
+    This is a regression test for issue #10588:
+    https://github.com/sympy/sympy/issues/10588
+    """
+    a = Symbol('0')
+    expr = Commutator(Bd(a)**2, B(a))
+    assert latex(expr) == r"-LDBrackets[b_{0},{b^dagger_{0}}^{2}RDBrackets]"

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/physics/secondquant\.py)' bin/test -C --verbose sympy/printing/tests/test_latex_double_superscript.p
cat coverage.cover
git checkout de446c6d85f633271dfec1452f6f28ea783e293f
git apply /root/pre_state.patch
