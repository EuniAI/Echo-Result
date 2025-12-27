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
diff --git a/astropy/units/tests/test_quantity_duck_typing.py b/astropy/units/tests/test_quantity_duck_typing.py
new file mode 100644
index 0000000000..b629b4072c
--- /dev/null
+++ b/astropy/units/tests/test_quantity_duck_typing.py
@@ -0,0 +1,49 @@
+import dataclasses
+
+import numpy as np
+import pytest
+
+from astropy import units as u
+
+
+# Per issue description: https://github.com/astropy/astropy/issues/11823
+@dataclasses.dataclass
+class DuckArray(np.lib.mixins.NDArrayOperatorsMixin):
+    """
+    Minimal duck type of astropy.units.Quantity defined in the issue.
+    See: https://github.com/astropy/astropy/issues/11823
+    """
+
+    ndarray: u.Quantity
+
+    @property
+    def unit(self) -> u.UnitBase:
+        return self.ndarray.unit
+
+    def __array_ufunc__(self, function, method, *inputs, **kwargs):
+        inputs = [inp.ndarray if isinstance(inp, DuckArray) else inp for inp in inputs]
+
+        for inp in inputs:
+            if isinstance(inp, np.ndarray):
+                result = inp.__array_ufunc__(function, method, *inputs, **kwargs)
+                if result is not NotImplemented:
+                    return DuckArray(result)
+
+        return NotImplemented
+
+
+def test_ufunc_duck_type_coercion_return_not_implemented():
+    """
+    Test that Quantity.__array_ufunc__ returns NotImplemented for
+    incompatible types, allowing for reflected operations on duck types.
+    """
+    # This operation currently fails with a ValueError.
+    # When fixed, Quantity.__array_ufunc__ should return NotImplemented,
+    # which will then call the __radd__ of the DuckArray, which is implemented
+    # via its own __array_ufunc__.
+    result = (1 * u.m) + DuckArray(1 * u.mm)
+
+    # The result of the reflected operation should be a DuckArray
+    # containing the correct value.
+    expected = DuckArray(1001 * u.mm)
+    assert result == expected

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/units/quantity\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/units/tests/test_quantity_duck_typing.py
cat coverage.cover
git checkout 5250b2442501e6c671c6b380536f1edb352602d1
git apply /root/pre_state.patch
