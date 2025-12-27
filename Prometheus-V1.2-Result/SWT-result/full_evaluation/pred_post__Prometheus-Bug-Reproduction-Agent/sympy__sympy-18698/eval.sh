#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3dff1b98a78f28c953ae2140b69356b8391e399c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3dff1b98a78f28c953ae2140b69356b8391e399c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/polys/polytools.py b/sympy/polys/polytools.py
--- a/sympy/polys/polytools.py
+++ b/sympy/polys/polytools.py
@@ -2,7 +2,8 @@
 
 from __future__ import print_function, division
 
-from functools import wraps
+from functools import wraps, reduce
+from operator import mul
 
 from sympy.core import (
     S, Basic, Expr, I, Integer, Add, Mul, Dummy, Tuple
@@ -5905,10 +5906,7 @@ def _symbolic_factor_list(expr, opt, method):
         if arg.is_Number:
             coeff *= arg
             continue
-        if arg.is_Mul:
-            args.extend(arg.args)
-            continue
-        if arg.is_Pow:
+        elif arg.is_Pow:
             base, exp = arg.args
             if base.is_Number and exp.is_Number:
                 coeff *= arg
@@ -5949,6 +5947,9 @@ def _symbolic_factor_list(expr, opt, method):
                         other.append((f, k))
 
                 factors.append((_factors_product(other), exp))
+    if method == 'sqf':
+        factors = [(reduce(mul, (f for f, _ in factors if _ == k)), k)
+                   for k in set(i for _, i in factors)]
 
     return coeff, factors
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/polys/tests/test_sqf_list.py b/sympy/polys/tests/test_sqf_list.py
new file mode 100644
index 0000000000..6dea8922e8
--- /dev/null
+++ b/sympy/polys/tests/test_sqf_list.py
@@ -0,0 +1,25 @@
+from sympy import Symbol
+from sympy.polys.polytools import sqf_list
+
+def test_sqf_list_groups_factors_with_same_multiplicity():
+    """
+    Test that sqf_list combines factors of the same multiplicity.
+
+    This is a regression test for a bug where factors with the same
+    multiplicity were returned as separate factors, instead of being
+    multiplied together.
+    """
+    x = Symbol('x')
+    poly = (x**2 + 1) * (x - 1)**2 * (x - 2)**3 * (x - 3)**3
+
+    _coeff, factors = sqf_list(poly)
+
+    # The bug is that factors with multiplicity 3 are not grouped.
+    # This isolates the factors that should be grouped.
+    factors_with_mult_3 = {p for p, k in factors if k == 3}
+
+    # When fixed, there should be one factor, the product of the two.
+    # With the bug, there will be two factors: {x - 2, x - 3}.
+    expected_factor = (x - 2)*(x - 3)
+
+    assert factors_with_mult_3 == {expected_factor}

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/polys/polytools\.py)' bin/test -C --verbose sympy/polys/tests/test_sqf_list.p
cat coverage.cover
git checkout 3dff1b98a78f28c953ae2140b69356b8391e399c
git apply /root/pre_state.patch
