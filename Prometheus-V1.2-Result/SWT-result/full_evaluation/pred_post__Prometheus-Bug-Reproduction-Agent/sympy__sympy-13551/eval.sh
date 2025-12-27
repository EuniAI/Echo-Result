#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9476425b9e34363c2d9ac38e9f04aa75ae54a775 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9476425b9e34363c2d9ac38e9f04aa75ae54a775
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/concrete/products.py b/sympy/concrete/products.py
--- a/sympy/concrete/products.py
+++ b/sympy/concrete/products.py
@@ -282,8 +282,8 @@ def _eval_product(self, term, limits):
                 # There is expression, which couldn't change by
                 # as_numer_denom(). E.g. n**(2/3) + 1 --> (n**(2/3) + 1, 1).
                 # We have to catch this case.
-
-                p = sum([self._eval_product(i, (k, a, n)) for i in p.as_coeff_Add()])
+                from sympy.concrete.summations import Sum
+                p = exp(Sum(log(p), (k, a, n)))
             else:
                 p = self._eval_product(p, (k, a, n))
             return p / q

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/concrete/tests/test_product_evaluation.py b/sympy/concrete/tests/test_product_evaluation.py
new file mode 100644
index 0000000000..82a455ebf8
--- /dev/null
+++ b/sympy/concrete/tests/test_product_evaluation.py
@@ -0,0 +1,29 @@
+from sympy import (
+    Abs, And, binomial, Catalan, cos, Derivative, E, Eq, exp, EulerGamma,
+    factorial, Function, harmonic, I, Integral, KroneckerDelta, log,
+    nan, Ne, Or, oo, pi, Piecewise, Product, product, Rational, S, simplify,
+    sin, sqrt, Sum, summation, Symbol, symbols, sympify, zeta, gamma, Le,
+    Indexed, Idx, IndexedBase, prod)
+from sympy.abc import a, b, c, d, f, k, m, x, y, z
+from sympy.concrete.summations import telescopic
+from sympy.utilities.pytest import XFAIL, raises
+from sympy.simplify import simplify
+from sympy.matrices import Matrix
+from sympy.core.mod import Mod
+from sympy.core.compatibility import range
+
+n = Symbol('n', integer=True)
+
+
+def test_product_pow_in_term():
+    """
+    Test for incorrect product evaluation involving powers.
+
+    The product Product(n + 1/2**k, (k, 0, n-1)) was being evaluated
+    incorrectly. This test checks the case for n=2.
+    The correct result is (2 + 1/2**0) * (2 + 1/2**1) = 3 * 5/2 = 15/2.
+    The buggy implementation gives 9/2.
+    """
+    p = Product(n + S(1)/2**k, (k, 0, n - 1))
+    evaluated_product = p.doit()
+    assert evaluated_product.subs(n, 2) == Rational(15, 2)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/concrete/products\.py)' bin/test -C --verbose sympy/concrete/tests/test_product_evaluation.p
cat coverage.cover
git checkout 9476425b9e34363c2d9ac38e9f04aa75ae54a775
git apply /root/pre_state.patch
