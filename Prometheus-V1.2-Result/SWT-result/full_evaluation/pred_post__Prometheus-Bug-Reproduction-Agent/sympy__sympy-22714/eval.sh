#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3ff4717b6aef6086e78f01cdfa06f64ae23aed7e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3ff4717b6aef6086e78f01cdfa06f64ae23aed7e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/geometry/point.py b/sympy/geometry/point.py
--- a/sympy/geometry/point.py
+++ b/sympy/geometry/point.py
@@ -152,7 +152,7 @@ def __new__(cls, *args, **kwargs):
                         'warn' or 'ignore'.'''))
         if any(coords[dim:]):
             raise ValueError('Nonzero coordinates cannot be removed.')
-        if any(a.is_number and im(a) for a in coords):
+        if any(a.is_number and im(a).is_zero is False for a in coords):
             raise ValueError('Imaginary coordinates are not permitted.')
         if not all(isinstance(a, Expr) for a in coords):
             raise TypeError('Coordinates must be valid SymPy expressions.')

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_sympify_bug.py b/sympy/core/tests/test_sympify_bug.py
new file mode 100644
index 0000000000..2d4e4a3699
--- /dev/null
+++ b/sympy/core/tests/test_sympify_bug.py
@@ -0,0 +1,14 @@
+from sympy.core.singleton import S
+from sympy.core.numbers import Integer
+from sympy.geometry import Point2D
+from sympy.core.parameters import evaluate
+
+
+def test_sympify_point_with_evaluate_false():
+    """
+    Test that sympifying a Point2D string with evaluate(False)
+    does not raise an exception.
+    """
+    with evaluate(False):
+        s = S('Point2D(Integer(1),Integer(2))')
+    assert s == Point2D(Integer(1), Integer(2))

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/geometry/point\.py)' bin/test -C --verbose sympy/core/tests/test_sympify_bug.p
cat coverage.cover
git checkout 3ff4717b6aef6086e78f01cdfa06f64ae23aed7e
git apply /root/pre_state.patch
