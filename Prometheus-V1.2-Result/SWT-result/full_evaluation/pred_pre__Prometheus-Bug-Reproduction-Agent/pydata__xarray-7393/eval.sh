#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 41fef6f1352be994cd90056d47440fe9aa4c068f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 41fef6f1352be994cd90056d47440fe9aa4c068f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_stack.py b/xarray/tests/test_stack.py
new file mode 100644
index 00000000..12459556
--- /dev/null
+++ b/xarray/tests/test_stack.py
@@ -0,0 +1,20 @@
+import numpy as np
+import xarray as xr
+
+
+def test_stack_preserves_int32_coord_dtype():
+    """
+    Test that stacking a coordinate with int32 dtype preserves the dtype.
+
+    This is a regression test for a bug where stacking a coordinate with an
+    int32 dtype would cause it to be upcast to int64 in the resulting
+    MultiIndex.
+    """
+    ds = xr.Dataset(coords={"a": np.array([0], dtype="i4")})
+    stacked = ds.stack(b=("a",))
+
+    # Directly check the dtype of the level in the underlying pandas.MultiIndex
+    actual_dtype = stacked.indexes["b"].get_level_values("a").dtype
+    expected_dtype = np.dtype("i4")
+
+    assert actual_dtype == expected_dtype

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/indexing\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_stack.py
cat coverage.cover
git checkout 41fef6f1352be994cd90056d47440fe9aa4c068f
git apply /root/pre_state.patch
