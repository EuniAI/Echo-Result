#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1757dffac2fa493d7b9a074b84cf8c830a706688 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1757dffac2fa493d7b9a074b84cf8c830a706688
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_copy.py b/xarray/tests/test_copy.py
new file mode 100644
index 00000000..40a87fc3
--- /dev/null
+++ b/xarray/tests/test_copy.py
@@ -0,0 +1,23 @@
+import numpy as np
+import pytest
+
+import xarray
+from xarray.testing import assert_identical
+
+
+class TestDataset:
+    def test_copy_deep_preserves_unicode_index_dtype(self):
+        """
+        Test that copying a Dataset with a unicode index preserves the
+        dtype and does not cast it to 'object'.
+
+        Regression test for a bug where copy(deep=True) would cast unicode
+        indices to object.
+        """
+        ds = xarray.Dataset(
+            coords={"x": ["foo"], "y": ("x", ["bar"])},
+            data_vars={"z": ("x", ["baz"])},
+        )
+        new = ds.copy(deep=True)
+
+        assert new["x"].dtype == ds["x"].dtype

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/indexing\.py|xarray/core/variable\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_copy.py
cat coverage.cover
git checkout 1757dffac2fa493d7b9a074b84cf8c830a706688
git apply /root/pre_state.patch
