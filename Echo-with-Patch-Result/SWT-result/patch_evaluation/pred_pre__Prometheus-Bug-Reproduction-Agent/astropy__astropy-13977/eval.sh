#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5250b2442501e6c671c6b380536f1edb352602d1 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5250b2442501e6c671c6b380536f1edb352602d1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/units/tests/test_ufunc_duck_type_coercion.py b/astropy/units/tests/test_ufunc_duck_type_coercion.py
new file mode 100644
index 0000000000..f8cbb39d10
--- /dev/null
+++ b/astropy/units/tests/test_ufunc_duck_type_coercion.py
@@ -0,0 +1,49 @@
+import dataclasses
+
+import numpy as np
+import pytest
+
+from astropy import units as u
+
+
+def test_ufunc_duck_type_coercion():
+    """
+    Test that __array_ufunc__ returns NotImplemented for incompatible
+    duck types, allowing the duck type to handle the operation.
+
+    Regression test for gh-11727.
+    """
+
+    @dataclasses.dataclass
+    class DuckArray(np.lib.mixins.NDArrayOperatorsMixin):
+        ndarray: u.Quantity
+
+        @property
+        def unit(self) -> u.UnitBase:
+            return self.ndarray.unit
+
+        def __array_ufunc__(self, function, method, *inputs, **kwargs):
+            inputs = [
+                inp.ndarray if isinstance(inp, DuckArray) else inp for inp in inputs
+            ]
+
+            for inp in inputs:
+                if isinstance(inp, np.ndarray):
+                    result = inp.__array_ufunc__(function, method, *inputs, **kwargs)
+                    if result is not NotImplemented:
+                        return DuckArray(result)
+
+            return NotImplemented
+
+    # Before the fix, this raises ValueError because Quantity.__array_ufunc__
+    # does not know how to handle DuckArray.
+    # With the fix, it returns NotImplemented, and DuckArray.__array_ufunc__
+    # is called, which handles the operation.
+    result = (1 * u.m) + DuckArray(1 * u.mm)
+
+    # DuckArray.__array_ufunc__ unwraps the DuckArray, calls
+    # Quantity.__array_ufunc__ with two Quantities, and then wraps
+    # the result in a new DuckArray.
+    expected = DuckArray(1.001 * u.m)
+
+    assert result == expected

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/units/quantity\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/units/tests/test_ufunc_duck_type_coercion.py
cat coverage.cover
git checkout 5250b2442501e6c671c6b380536f1edb352602d1
git apply /root/pre_state.patch
