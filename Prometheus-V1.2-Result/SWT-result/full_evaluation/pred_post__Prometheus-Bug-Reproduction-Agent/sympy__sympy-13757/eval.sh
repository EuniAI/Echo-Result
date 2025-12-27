#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a5e6a101869e027e7930e694f8b1cfb082603453 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a5e6a101869e027e7930e694f8b1cfb082603453
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/polys/polytools.py b/sympy/polys/polytools.py
--- a/sympy/polys/polytools.py
+++ b/sympy/polys/polytools.py
@@ -106,6 +106,7 @@ class Poly(Expr):
 
     is_commutative = True
     is_Poly = True
+    _op_priority = 10.001
 
     def __new__(cls, rep, *gens, **args):
         """Create a new polynomial instance out of something useful. """

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/polys/tests/test_poly_multiplication.py b/sympy/polys/tests/test_poly_multiplication.py
new file mode 100644
index 0000000000..45fa2183e3
--- /dev/null
+++ b/sympy/polys/tests/test_poly_multiplication.py
@@ -0,0 +1,71 @@
+from sympy.polys.polytools import (
+    Poly, PurePoly, poly,
+    parallel_poly_from_expr,
+    degree, degree_list,
+    total_degree,
+    LC, LM, LT,
+    pdiv, prem, pquo, pexquo,
+    div, rem, quo, exquo,
+    half_gcdex, gcdex, invert,
+    subresultants,
+    resultant, discriminant,
+    terms_gcd, cofactors,
+    gcd, gcd_list,
+    lcm, lcm_list,
+    trunc,
+    monic, content, primitive,
+    compose, decompose,
+    sturm,
+    gff_list, gff,
+    sqf_norm, sqf_part, sqf_list, sqf,
+    factor_list, factor,
+    intervals, refine_root, count_roots,
+    real_roots, nroots, ground_roots,
+    nth_power_roots_poly,
+    cancel, reduced, groebner,
+    GroebnerBasis, is_zero_dimensional,
+    _torational_factor_list,
+    to_rational_coeffs)
+
+from sympy.polys.polyerrors import (
+    MultivariatePolynomialError,
+    ExactQuotientFailed,
+    PolificationFailed,
+    ComputationFailed,
+    UnificationFailed,
+    RefinementFailed,
+    GeneratorsNeeded,
+    GeneratorsError,
+    PolynomialError,
+    CoercionFailed,
+    DomainError,
+    OptionError,
+    FlagError)
+
+from sympy.polys.polyclasses import DMP
+
+from sympy.polys.fields import field
+from sympy.polys.domains import FF, ZZ, QQ, RR, EX
+from sympy.polys.domains.realfield import RealField
+from sympy.polys.orderings import lex, grlex, grevlex
+
+from sympy import (
+    S, Integer, Rational, Float, Mul, Symbol, sqrt, Piecewise, Derivative,
+    exp, sin, tanh, expand, oo, I, pi, re, im, rootof, Eq, Tuple, Expr, diff)
+
+from sympy.core.basic import _aresame
+from sympy.core.compatibility import iterable
+from sympy.core.mul import _keep_coeff
+from sympy.utilities.pytest import raises, XFAIL
+from sympy.simplify import simplify
+
+from sympy.abc import a, b, c, d, p, q, t, w, x, y, z
+from sympy import MatrixSymbol
+
+
+def test_poly_multiplication_by_expression_on_left():
+    """
+    Test that multiplying an expression by a Poly evaluates correctly
+    when the expression is on the left side of the multiplication.
+    """
+    assert x * Poly(x) == Poly(x**2)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/polys/polytools\.py)' bin/test -C --verbose sympy/polys/tests/test_poly_multiplication.p
cat coverage.cover
git checkout a5e6a101869e027e7930e694f8b1cfb082603453
git apply /root/pre_state.patch
