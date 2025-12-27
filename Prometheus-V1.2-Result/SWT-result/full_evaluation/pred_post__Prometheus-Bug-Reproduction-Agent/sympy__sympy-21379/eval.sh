#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 624217179aaf8d094e6ff75b7493ad1ee47599b0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 624217179aaf8d094e6ff75b7493ad1ee47599b0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/mod.py b/sympy/core/mod.py
--- a/sympy/core/mod.py
+++ b/sympy/core/mod.py
@@ -40,6 +40,7 @@ def eval(cls, p, q):
         from sympy.core.mul import Mul
         from sympy.core.singleton import S
         from sympy.core.exprtools import gcd_terms
+        from sympy.polys.polyerrors import PolynomialError
         from sympy.polys.polytools import gcd
 
         def doit(p, q):
@@ -166,10 +167,13 @@ def doit(p, q):
         # XXX other possibilities?
 
         # extract gcd; any further simplification should be done by the user
-        G = gcd(p, q)
-        if G != 1:
-            p, q = [
-                gcd_terms(i/G, clear=False, fraction=False) for i in (p, q)]
+        try:
+            G = gcd(p, q)
+            if G != 1:
+                p, q = [gcd_terms(i/G, clear=False, fraction=False)
+                        for i in (p, q)]
+        except PolynomialError:  # issue 21373
+            G = S.One
         pwas, qwas = p, q
 
         # simplify terms

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_subs_issues.py b/sympy/core/tests/test_subs_issues.py
new file mode 100644
index 0000000000..7b764c12ec
--- /dev/null
+++ b/sympy/core/tests/test_subs_issues.py
@@ -0,0 +1,23 @@
+from sympy.polys.polyerrors import PolynomialError
+from sympy import symbols, exp, sinh, Piecewise
+from sympy.core.cache import clear_cache
+
+
+def test_issue_21121_subs_on_piecewise_with_real_symbols():
+    """
+    Test for unexpected PolynomialError from subs() for specific expressions.
+
+    This test reproduces the bug from issue #21121, where subs() fails on a
+    particular expression involving sinh and a Piecewise function with real
+    symbols. The correct behavior is for the substitution to complete without
+    raising an error.
+
+    This test will fail with a PolynomialError if the bug is present and
+    will pass once the bug has been fixed.
+    """
+    clear_cache()
+    x, y, z = symbols('x y z', real=True)
+    expr = exp(sinh(Piecewise((x, y > x), (y, True)) / z))
+    # This was raising "PolynomialError: Piecewise generators do not make sense"
+    # The substitution should not raise an error.
+    assert expr.subs({1: 1.0}) == expr

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/mod\.py)' bin/test -C --verbose sympy/core/tests/test_subs_issues.p
cat coverage.cover
git checkout 624217179aaf8d094e6ff75b7493ad1ee47599b0
git apply /root/pre_state.patch
