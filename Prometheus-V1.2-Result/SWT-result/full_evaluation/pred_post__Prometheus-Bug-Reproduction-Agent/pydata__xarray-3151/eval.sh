#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 118f4d996e7711c9aced916e6049af9f28d5ec66 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 118f4d996e7711c9aced916e6049af9f28d5ec66
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/core/combine.py b/xarray/core/combine.py
--- a/xarray/core/combine.py
+++ b/xarray/core/combine.py
@@ -501,14 +501,13 @@ def combine_by_coords(datasets, compat='no_conflicts', data_vars='all',
                                    fill_value=fill_value)
 
         # Check the overall coordinates are monotonically increasing
-        for dim in concatenated.dims:
-            if dim in concatenated:
-                indexes = concatenated.indexes.get(dim)
-                if not (indexes.is_monotonic_increasing
-                        or indexes.is_monotonic_decreasing):
-                    raise ValueError("Resulting object does not have monotonic"
-                                     " global indexes along dimension {}"
-                                     .format(dim))
+        for dim in concat_dims:
+            indexes = concatenated.indexes.get(dim)
+            if not (indexes.is_monotonic_increasing
+                    or indexes.is_monotonic_decreasing):
+                raise ValueError("Resulting object does not have monotonic"
+                                 " global indexes along dimension {}"
+                                 .format(dim))
         concatenated_grouped_by_data_vars.append(concatenated)
 
     return merge(concatenated_grouped_by_data_vars, compat=compat,

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/xarray/tests/test_combine_by_coords.py b/xarray/tests/test_combine_by_coords.py
new file mode 100644
index 00000000..022fd907
--- /dev/null
+++ b/xarray/tests/test_combine_by_coords.py
@@ -0,0 +1,40 @@
+import numpy as np
+import pytest
+
+from xarray import Dataset, combine_by_coords, concat
+from xarray.testing import assert_identical
+
+
+def test_combine_by_coords_nonmonotonic_identical_coords():
+    """
+    Test that combine_by_coords does not raise an error for identical but
+    non-monotonic coordinates.
+
+    Regression test for GH #3142.
+    """
+    y_coord = ['a', 'c', 'b']
+
+    ds1 = Dataset(
+        data_vars=dict(
+            data=(['x', 'y'], np.arange(9).reshape(3, 3))
+        ),
+        coords=dict(
+            x=[1, 2, 3],
+            y=y_coord
+        )
+    )
+
+    ds2 = Dataset(
+        data_vars=dict(
+            data=(['x', 'y'], np.arange(9, 21).reshape(4, 3))
+        ),
+        coords=dict(
+            x=[4, 5, 6, 7],
+            y=y_coord
+        )
+    )
+
+    result = combine_by_coords((ds1, ds2))
+    expected = concat([ds1, ds2], dim='x')
+
+    assert_identical(result, expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(xarray/core/combine\.py)' -m pytest --no-header -rA  -p no:cacheprovider xarray/tests/test_combine_by_coords.py
cat coverage.cover
git checkout 118f4d996e7711c9aced916e6049af9f28d5ec66
git apply /root/pre_state.patch
