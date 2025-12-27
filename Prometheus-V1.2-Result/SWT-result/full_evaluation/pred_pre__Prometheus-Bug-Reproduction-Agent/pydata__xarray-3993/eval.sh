#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 8cc34cb412ba89ebca12fc84f76a9e452628f1bc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 8cc34cb412ba89ebca12fc84f76a9e452628f1bc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_dataarray_integrate.py b/xarray/tests/test_dataarray_integrate.py
new file mode 100644
index 00000000..ee64f142
--- /dev/null
+++ b/xarray/tests/test_dataarray_integrate.py
@@ -0,0 +1,17 @@
+import numpy as np
+import pytest
+
+import xarray as xr
+from xarray import DataArray
+from xarray.tests import assert_allclose
+
+
+def test_dataarray_integrate_coord_kwarg():
+    """
+    Test that DataArray.integrate accepts 'coord' as an argument for
+    consistency with Dataset.integrate.
+    """
+    da = DataArray([1, 2, 3], coords={"x": [0, 1, 2]}, dims="x")
+    expected = da.integrate(dim="x")
+    actual = da.integrate(coord="x")
+    assert_allclose(actual, expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/dataset\.py|xarray/core/dataarray\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_dataarray_integrate.py
cat coverage.cover
git checkout 8cc34cb412ba89ebca12fc84f76a9e452628f1bc
git apply /root/pre_state.patch
