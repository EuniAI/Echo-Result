#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e8c22f6eac7314be8d92590bfff92ced79ee03e2 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e8c22f6eac7314be8d92590bfff92ced79ee03e2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/units/unitsystem.py b/sympy/physics/units/unitsystem.py
--- a/sympy/physics/units/unitsystem.py
+++ b/sympy/physics/units/unitsystem.py
@@ -175,7 +175,7 @@ def _collect_factor_and_dimension(self, expr):
             for addend in expr.args[1:]:
                 addend_factor, addend_dim = \
                     self._collect_factor_and_dimension(addend)
-                if dim != addend_dim:
+                if not self.get_dimension_system().equivalent_dims(dim, addend_dim):
                     raise ValueError(
                         'Dimension of "{}" is {}, '
                         'but it should be {}'.format(

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/units/tests/test_unit_collections.py b/sympy/physics/units/tests/test_unit_collections.py
new file mode 100644
index 0000000000..5e6d0f2c04
--- /dev/null
+++ b/sympy/physics/units/tests/test_unit_collections.py
@@ -0,0 +1,33 @@
+from sympy.physics.units.definitions import meter, second
+from sympy.physics.units.definitions.dimension_definitions import (
+    velocity, acceleration, time, Dimension
+)
+from sympy.physics.units.quantities import Quantity
+from sympy.physics.units.systems import SI
+
+
+def test_equivalent_dimension_in_addition():
+    """
+    Test that collect_factor_and_dimension detects equivalent
+    dimensions in addition, for example acceleration*time and velocity.
+    """
+    v1 = Quantity('v1')
+    SI.set_quantity_dimension(v1, velocity)
+    SI.set_quantity_scale_factor(v1, 2 * meter / second)
+
+    a1 = Quantity('a1')
+    SI.set_quantity_dimension(a1, acceleration)
+    SI.set_quantity_scale_factor(a1, -9.8 * meter / second**2)
+
+    t1 = Quantity('t1')
+    SI.set_quantity_dimension(t1, time)
+    SI.set_quantity_scale_factor(t1, 5 * second)
+
+    expr1 = a1*t1 + v1
+    # In the failing case, this raises ValueError.
+    # After the fix it should correctly compute the factor and dimension.
+    # Factor: -9.8 * 5 + 2 = -47
+    # Dimension: acceleration*time is equivalent to velocity.
+    factor, dim = SI._collect_factor_and_dimension(expr1)
+    assert factor == -47
+    assert dim == velocity

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/physics/units/unitsystem\.py)' bin/test -C --verbose sympy/physics/units/tests/test_unit_collections.p
cat coverage.cover
git checkout e8c22f6eac7314be8d92590bfff92ced79ee03e2
git apply /root/pre_state.patch
