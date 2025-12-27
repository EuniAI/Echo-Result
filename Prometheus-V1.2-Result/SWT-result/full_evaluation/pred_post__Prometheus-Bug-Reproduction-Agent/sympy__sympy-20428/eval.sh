#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c0e85160406f9bf2bcaa2992138587668a1cd0bc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c0e85160406f9bf2bcaa2992138587668a1cd0bc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/polys/domains/expressiondomain.py b/sympy/polys/domains/expressiondomain.py
--- a/sympy/polys/domains/expressiondomain.py
+++ b/sympy/polys/domains/expressiondomain.py
@@ -120,7 +120,7 @@ def __ne__(f, g):
             return not f == g
 
         def __bool__(f):
-            return f.ex != 0
+            return not f.ex.is_zero
 
         def gcd(f, g):
             from sympy.polys import gcd

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/polys/tests/test_regressions.py b/sympy/polys/tests/test_regressions.py
new file mode 100644
index 0000000000..e6fee60711
--- /dev/null
+++ b/sympy/polys/tests/test_regressions.py
@@ -0,0 +1,22 @@
+from sympy.polys.polytools import Poly
+from sympy import sympify, symbols, sqrt
+
+
+def test_clear_denoms_unstripped_zero():
+    """
+    Test that a Poly that becomes zero after clear_denoms() is correctly
+    identified as a zero polynomial.
+
+    This is a regression test for an issue where a complex constant expression
+    simplifying to zero would result in a Poly object that reported
+    `is_zero` as False due to an unstripped zero in its internal DMP
+    representation, leading to errors in other methods like `terms_gcd()`.
+    """
+    x = symbols("x")
+    f = Poly(sympify("-117968192370600*18**(1/3)/(217603955769048*(24201 + 253*sqrt(9165))**(1/3) + 2273005839412*sqrt(9165)*(24201 + 253*sqrt(9165))**(1/3)) - 15720318185*2**(2/3)*3**(1/3)*(24201 + 253*sqrt(9165))**(2/3)/(217603955769048*(24201 + 253*sqrt(9165))**(1/3) + 2273005839412*sqrt(9165)*(24201 + 253*sqrt(9165))**(1/3)) + 15720318185*12**(1/3)*(24201 + 253*sqrt(9165))**(2/3)/(217603955769048*(24201 + 253*sqrt(9165))**(1/3) + 2273005839412*sqrt(9165)*(24201 + 253*sqrt(9165))**(1/3)) + 117968192370600*2**(1/3)*3**(2/3)/(217603955769048*(24201 + 253*sqrt(9165))**(1/3) + 2273005839412*sqrt(9165)*(24201 + 253*sqrt(9165))**(1/3))"), x)
+    _coeff, bad_poly = f.clear_denoms()
+
+    # The bug causes bad_poly to have an internal representation of
+    # DMP([EX(0)], EX, None) which should be DMP([], EX, None).
+    # This made is_zero return False.
+    assert bad_poly.is_zero

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/polys/domains/expressiondomain\.py)' bin/test -C --verbose sympy/polys/tests/test_regressions.p
cat coverage.cover
git checkout c0e85160406f9bf2bcaa2992138587668a1cd0bc
git apply /root/pre_state.patch
