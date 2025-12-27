#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 514579c655bf22e2af14f0743376ae1d7befe345 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 514579c655bf22e2af14f0743376ae1d7befe345
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/units/unitsystem.py b/sympy/physics/units/unitsystem.py
--- a/sympy/physics/units/unitsystem.py
+++ b/sympy/physics/units/unitsystem.py
@@ -190,10 +190,9 @@ def _collect_factor_and_dimension(self, expr):
                 dim /= idim**count
             return factor, dim
         elif isinstance(expr, Function):
-            fds = [self._collect_factor_and_dimension(
-                arg) for arg in expr.args]
-            return (expr.func(*(f[0] for f in fds)),
-                    *(d[1] for d in fds))
+            fds = [self._collect_factor_and_dimension(arg) for arg in expr.args]
+            dims = [Dimension(1) if self.get_dimension_system().is_dimensionless(d[1]) else d[1] for d in fds]
+            return (expr.func(*(f[0] for f in fds)), *dims)
         elif isinstance(expr, Dimension):
             return S.One, expr
         else:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/units/tests/test_si.py b/sympy/physics/units/tests/test_si.py
new file mode 100644
index 0000000000..edbcc7490c
--- /dev/null
+++ b/sympy/physics/units/tests/test_si.py
@@ -0,0 +1,39 @@
+from sympy.core.numbers import Rational
+from sympy.functions.elementary.exponential import exp
+from sympy.functions.elementary.miscellaneous import sqrt
+from sympy.physics.units import second, ohm, farad
+from sympy.physics.units.definitions import meter
+from sympy.physics.units.definitions.dimension_definitions import Dimension
+from sympy.physics.units.quantities import Quantity
+from sympy.physics.units.systems import SI
+from sympy.testing.pytest import raises
+
+
+def test_check_unit_consistency():
+    u = Quantity("u")
+    v = Quantity("v")
+    w = Quantity("w")
+
+    u.set_global_relative_scale_factor(10, meter)
+    v.set_global_relative_scale_factor(5, meter)
+    w.set_global_relative_scale_factor(2, second)
+
+    def check_unit_consistency(expr):
+        SI._collect_factor_and_dimension(expr)
+
+    raises(ValueError, lambda: check_unit_consistency(u + w))
+    raises(ValueError, lambda: check_unit_consistency(u - w))
+    raises(ValueError, lambda: check_unit_consistency(u + 1))
+    raises(ValueError, lambda: check_unit_consistency(u - 1))
+    raises(ValueError, lambda: check_unit_consistency(1 - exp(u / w)))
+
+
+def test_dimensionless_exponent():
+    """
+    Test from issue that SI._collect_factor_and_dimension() can
+    properly detect that an exponent is dimensionless.
+    """
+    expr = second / (ohm * farad)
+    buggy_expr = 100 + exp(expr)
+    _factor, dim = SI._collect_factor_and_dimension(buggy_expr)
+    assert dim == Dimension(1)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/physics/units/unitsystem\.py)' bin/test -C --verbose sympy/physics/units/tests/test_si.p
cat coverage.cover
git checkout 514579c655bf22e2af14f0743376ae1d7befe345
git apply /root/pre_state.patch
