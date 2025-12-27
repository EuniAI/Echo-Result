#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9cbea134220b0b951587e11b63e2c832c7246cbc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9cbea134220b0b951587e11b63e2c832c7246cbc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/utilities/tests/test_lambdify_rational.py b/sympy/utilities/tests/test_lambdify_rational.py
new file mode 100644
index 0000000000..4f02932f88
--- /dev/null
+++ b/sympy/utilities/tests/test_lambdify_rational.py
@@ -0,0 +1,32 @@
+import mpmath
+import inspect
+from sympy.utilities.pytest import XFAIL, raises
+from sympy import (
+    symbols, lambdify, sqrt, sin, cos, tan, pi, acos, acosh, Rational,
+    Float, Matrix, Lambda, Piecewise, exp, Integral, oo, I, Abs, Function,
+    true, false, And, Or, Not, ITE, Min, Max, floor, diff, IndexedBase, Sum,
+    DotProduct, Eq, Dummy, sinc, S)
+from sympy.printing.lambdarepr import LambdaPrinter
+from sympy.utilities.lambdify import implemented_function
+from sympy.utilities.pytest import skip
+from sympy.utilities.decorator import conserve_mpmath_dps
+from sympy.external import import_module
+from sympy.functions.special.gamma_functions import uppergamma, lowergamma, RisingFactorial
+
+w, x, y, z = symbols('w,x,y,z')
+
+def test_lambdify_mpmath_rational():
+    """
+    Test that lambdify with mpmath module wraps rationals.
+
+    Based on https://github.com/sympy/sympy/pull/14971, where rationals
+    were not being converted to mpmath objects, resulting in precision loss.
+    """
+    expr = RisingFactorial(18, x) - (77 + S(1)/3)
+    f = lambdify(x, expr, 'mpmath')
+    src = inspect.getsource(f)
+
+    # The bug causes the rational to be printed as a standard Python float division
+    # which results in precision loss.
+    # A fixed version should use mpmath's high-precision objects.
+    assert '232/3' not in src

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/printing/pycode\.py)' bin/test -C --verbose sympy/utilities/tests/test_lambdify_rational.p
cat coverage.cover
git checkout 9cbea134220b0b951587e11b63e2c832c7246cbc
git apply /root/pre_state.patch
