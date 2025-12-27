#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5ca694b38d861c0e24cd8743753427dda839b90b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5ca694b38d861c0e24cd8743753427dda839b90b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/axes/_axes.py b/lib/matplotlib/axes/_axes.py
--- a/lib/matplotlib/axes/_axes.py
+++ b/lib/matplotlib/axes/_axes.py
@@ -5014,7 +5014,7 @@ def reduce_C_function(C: array) -> float
             if mincnt is None:
                 mincnt = 0
             accum = np.array(
-                [reduce_C_function(acc) if len(acc) > mincnt else np.nan
+                [reduce_C_function(acc) if len(acc) >= mincnt else np.nan
                  for Cs_at_i in [Cs_at_i1, Cs_at_i2]
                  for acc in Cs_at_i[1:]],  # [1:] drops out-of-range points.
                 float)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_hexbin.py b/lib/matplotlib/tests/test_hexbin.py
new file mode 100644
index 0000000000..18e5f2b780
--- /dev/null
+++ b/lib/matplotlib/tests/test_hexbin.py
@@ -0,0 +1,42 @@
+import numpy as np
+import matplotlib.pyplot as plt
+
+
+def test_hexbin_mincnt_with_C():
+    """
+    Test that hexbin's mincnt parameter is consistent when C is provided.
+
+    When the C parameter is provided to hexbin, the filtering of bins
+    by mincnt is inconsistent with the case where C is not provided.
+    This test checks that the number of hexagons drawn is the same
+    in both cases, as would be expected.
+    """
+    # Setup from the bug report to reproduce the issue
+    np.random.seed(42)
+    x, y = np.random.multivariate_normal(
+        [0.0, 0.0], [[1.0, 0.1], [0.1, 1.0]], size=250
+    ).T
+    z = np.ones_like(x)
+    extent = [-3.0, 3.0, -3.0, 3.0]
+    gridsize = (7, 7)
+
+    fig, ax = plt.subplots()
+
+    # Case 1: No C argument, mincnt=1. This is the correct behavior.
+    coll_no_C = ax.hexbin(x, y, mincnt=1, extent=extent, gridsize=gridsize)
+    ax.clear()
+
+    # Case 2: C argument supplied, mincnt=1. This is the buggy behavior.
+    coll_with_C = ax.hexbin(
+        x,
+        y,
+        C=z,
+        reduce_C_function=np.sum,
+        mincnt=1,
+        extent=extent,
+        gridsize=gridsize,
+    )
+
+    # The number of hexagons drawn should be the same in both cases.
+    # This fails because with C, mincnt is treated as a strict inequality.
+    assert len(coll_no_C.get_array()) == len(coll_with_C.get_array())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/axes/_axes\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_hexbin.py
cat coverage.cover
git checkout 5ca694b38d861c0e24cd8743753427dda839b90b
git apply /root/pre_state.patch
