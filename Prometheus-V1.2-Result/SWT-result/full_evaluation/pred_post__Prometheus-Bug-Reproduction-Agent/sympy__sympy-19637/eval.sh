#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 63f8f465d48559fecb4e4bf3c48b75bf15a3e0ef >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 63f8f465d48559fecb4e4bf3c48b75bf15a3e0ef
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/sympify.py b/sympy/core/sympify.py
--- a/sympy/core/sympify.py
+++ b/sympy/core/sympify.py
@@ -513,7 +513,9 @@ def kernS(s):
             while kern in s:
                 kern += choice(string.ascii_letters + string.digits)
             s = s.replace(' ', kern)
-        hit = kern in s
+            hit = kern in s
+        else:
+            hit = False
 
     for i in range(2):
         try:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_kerns.py b/sympy/core/tests/test_kerns.py
new file mode 100644
index 0000000000..f0d530ea9e
--- /dev/null
+++ b/sympy/core/tests/test_kerns.py
@@ -0,0 +1,30 @@
+from sympy import (Symbol, exp, Integer, Float, sin, cos, log, Poly, Lambda,
+    Function, I, S, sqrt, srepr, Rational, Tuple, Matrix, Interval, Add, Mul,
+    Pow, Or, true, false, Abs, pi, Range, Xor)
+from sympy.abc import x, y
+from sympy.core.sympify import (sympify, _sympify, SympifyError, kernS,
+    CantSympify)
+from sympy.core.decorators import _sympifyit
+from sympy.external import import_module
+from sympy.testing.pytest import raises, XFAIL, skip, warns_deprecated_sympy
+from sympy.utilities.decorator import conserve_mpmath_dps
+from sympy.geometry import Point, Line
+from sympy.functions.combinatorial.factorials import factorial, factorial2
+from sympy.abc import _clash, _clash1, _clash2
+from sympy.core.compatibility import exec_, HAS_GMPY
+from sympy.sets import FiniteSet, EmptySet
+from sympy.tensor.array.dense_ndim_array import ImmutableDenseNDimArray
+
+import mpmath
+from collections import defaultdict, OrderedDict
+from mpmath.rational import mpq
+
+
+numpy = import_module('numpy')
+
+
+def test_kernS_unbound_local_error():
+    """Test that kernS can parse expressions containing division."""
+    text = "(2*x)/(x-1)"
+    expr = kernS(text)
+    assert expr == 2*x/(x - 1)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/sympify\.py)' bin/test -C --verbose sympy/core/tests/test_kerns.p
cat coverage.cover
git checkout 63f8f465d48559fecb4e4bf3c48b75bf15a3e0ef
git apply /root/pre_state.patch
