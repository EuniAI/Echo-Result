#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3aa75c8d00a4a2d4acf10d80f76b937cadb666b7 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3aa75c8d00a4a2d4acf10d80f76b937cadb666b7
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_where.py b/xarray/tests/test_where.py
new file mode 100644
index 00000000..47efc295
--- /dev/null
+++ b/xarray/tests/test_where.py
@@ -0,0 +1,17 @@
+import pytest
+import xarray as xr
+from xarray.testing import assert_identical
+
+
+def test_where_keep_attrs_coord_attributes():
+    """
+    Test that ``xr.where`` with ``keep_attrs=True`` preserves coordinate
+    attributes.
+
+    Regression test for GH6982.
+    """
+    ds = xr.tutorial.load_dataset("air_temperature")
+    expected_coord = ds.air.time
+    actual = xr.where(True, ds.air, ds.air, keep_attrs=True)
+
+    assert_identical(expected_coord, actual.time)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/computation\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_where.py
cat coverage.cover
git checkout 3aa75c8d00a4a2d4acf10d80f76b937cadb666b7
git apply /root/pre_state.patch
