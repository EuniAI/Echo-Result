#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ef6e6a7b86f8479b9a1fecf15ad5b88a2326b31e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ef6e6a7b86f8479b9a1fecf15ad5b88a2326b31e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_merge_bug.py b/xarray/tests/test_merge_bug.py
new file mode 100644
index 00000000..28787363
--- /dev/null
+++ b/xarray/tests/test_merge_bug.py
@@ -0,0 +1,14 @@
+import pytest
+import xarray as xr
+
+
+class TestMergeMethod:
+    def test_merge_dataarray_from_dataset(self):
+        """Test merging a DataArray into a Dataset using the Dataset.merge method."""
+        ds = xr.Dataset({"a": 0})
+        da = xr.DataArray(1, name="b")
+
+        expected = xr.merge([ds, da])
+        actual = ds.merge(da)
+
+        assert actual.identical(expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/dataset\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_merge_bug.py
cat coverage.cover
git checkout ef6e6a7b86f8479b9a1fecf15ad5b88a2326b31e
git apply /root/pre_state.patch
