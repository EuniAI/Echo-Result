#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 50d8a102f0735da8e165a0369bbb994c7d0592a6 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 50d8a102f0735da8e165a0369bbb994c7d0592a6
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/sets/tests/test_complement.py b/sympy/sets/tests/test_complement.py
new file mode 100644
index 0000000000..c3bd50e1bf
--- /dev/null
+++ b/sympy/sets/tests/test_complement.py
@@ -0,0 +1,19 @@
+from sympy import (Symbol, Set, Union, Interval, oo, S, sympify, nan,
+    GreaterThan, LessThan, Max, Min, And, Or, Eq, Ge, Le, Gt, Lt, Float,
+    FiniteSet, Intersection, imageset, I, true, false, ProductSet, E,
+    sqrt, Complement, EmptySet, sin, cos, Lambda, ImageSet, pi,
+    Eq, Pow, Contains, Sum, rootof, SymmetricDifference, Piecewise,
+    Matrix, signsimp, Range)
+from mpmath import mpi
+
+from sympy.core.compatibility import range
+from sympy.utilities.pytest import raises, XFAIL
+
+from sympy.abc import x, y, z, m, n
+
+
+def test_complement_finiteset_mixture_of_symbols_and_numbers():
+    a = FiniteSet(x, y, 2)
+    b = Interval(-10, 10)
+    assert Complement(a, b) == Complement(FiniteSet(x, y), b)
+

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/sets/sets\.py)' bin/test -C --verbose sympy/sets/tests/test_complement.p
cat coverage.cover
git checkout 50d8a102f0735da8e165a0369bbb994c7d0592a6
git apply /root/pre_state.patch
