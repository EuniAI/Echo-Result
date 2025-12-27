#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 493d608e39d32a67173c23a7bbc47d6bfedcef61 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 493d608e39d32a67173c23a7bbc47d6bfedcef61
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/axes/_base.py b/lib/matplotlib/axes/_base.py
--- a/lib/matplotlib/axes/_base.py
+++ b/lib/matplotlib/axes/_base.py
@@ -2434,7 +2434,7 @@ def _update_patch_limits(self, patch):
         # Get all vertices on the path
         # Loop through each segment to get extrema for Bezier curve sections
         vertices = []
-        for curve, code in p.iter_bezier():
+        for curve, code in p.iter_bezier(simplify=False):
             # Get distance along the curve of any extrema
             _, dzeros = curve.axis_aligned_extrema()
             # Calculate vertices of start, end and any extrema in between

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_hist.py b/lib/matplotlib/tests/test_hist.py
new file mode 100644
index 0000000000..1b1bcf4850
--- /dev/null
+++ b/lib/matplotlib/tests/test_hist.py
@@ -0,0 +1,26 @@
+import numpy as np
+import matplotlib.pyplot as plt
+
+
+def test_hist_step_density_autoscale():
+    """
+    Test that ax.hist with density=True and histtype='step' autoscales the
+    y-axis correctly.
+
+    The bug is that the y-axis is not scaled to the data, resulting in a
+    plot where the histogram is clipped or not visible. This test checks
+    that the upper y-limit is greater than or equal to the maximum value of
+    the histogram. This is a regression test for #24113.
+    """
+    np.random.seed(19680801)
+    scale = 1.2
+    data = np.random.randn(100000) * scale
+    bins = 100
+
+    fig, ax = plt.subplots()
+    # n is the array of values for the histogram bins.
+    n, _, _ = ax.hist(data, bins=bins, density=True, histtype='step')
+
+    # The y-axis limit must be large enough to show the histogram.
+    # Due to the bug, the ylim is not set correctly for histtype='step'.
+    assert ax.get_ylim()[1] >= np.max(n)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/axes/_base\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_hist.py
cat coverage.cover
git checkout 493d608e39d32a67173c23a7bbc47d6bfedcef61
git apply /root/pre_state.patch
