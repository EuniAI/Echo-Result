#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b7ce415c15eb39b026a097a2865da73fbcf15c9c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b7ce415c15eb39b026a097a2865da73fbcf15c9c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/image.py b/lib/matplotlib/image.py
--- a/lib/matplotlib/image.py
+++ b/lib/matplotlib/image.py
@@ -532,9 +532,9 @@ def _make_image(self, A, in_bbox, out_bbox, clip_bbox, magnification=1.0,
                 # we have re-set the vmin/vmax to account for small errors
                 # that may have moved input values in/out of range
                 s_vmin, s_vmax = vrange
-                if isinstance(self.norm, mcolors.LogNorm):
-                    if s_vmin < 0:
-                        s_vmin = max(s_vmin, np.finfo(scaled_dtype).eps)
+                if isinstance(self.norm, mcolors.LogNorm) and s_vmin <= 0:
+                    # Don't give 0 or negative values to LogNorm
+                    s_vmin = np.finfo(scaled_dtype).eps
                 with cbook._setattr_cm(self.norm,
                                        vmin=s_vmin,
                                        vmax=s_vmax,

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_colors_lognorm.py b/lib/matplotlib/tests/test_colors_lognorm.py
new file mode 100644
index 0000000000..2dd122e5e9
--- /dev/null
+++ b/lib/matplotlib/tests/test_colors_lognorm.py
@@ -0,0 +1,22 @@
+import numpy as np
+import pytest
+
+from matplotlib import pyplot as plt
+from matplotlib import colors
+
+
+def test_huge_range_log_draw():
+    """
+    Test that drawing an image with LogNorm and a huge range does not error.
+
+    This is a regression test for an intermittent bug that caused ``LogNorm``
+    to fail with ``ValueError: Invalid vmin or vmax``, particularly in CI.
+    The test simply needs to complete a draw without raising an exception.
+    """
+    fig, ax = plt.subplots()
+    data = np.full((5, 5), -1, dtype=np.float64)
+    data[0:2, :] = 1E20
+    ax.imshow(data, norm=colors.LogNorm(vmin=100, vmax=data.max()))
+    fig.canvas.draw()
+    # No explicit assertion needed. The test fails if draw() raises an
+    # exception, and passes if it completes without error.

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/image\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_colors_lognorm.py
cat coverage.cover
git checkout b7ce415c15eb39b026a097a2865da73fbcf15c9c
git apply /root/pre_state.patch
