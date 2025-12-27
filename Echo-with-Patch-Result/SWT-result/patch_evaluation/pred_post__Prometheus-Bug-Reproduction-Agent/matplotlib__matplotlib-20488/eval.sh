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
diff --git a/lib/matplotlib/tests/test_imshow_lognorm_huge_range.py b/lib/matplotlib/tests/test_imshow_lognorm_huge_range.py
new file mode 100644
index 0000000000..21dbd8a2ce
--- /dev/null
+++ b/lib/matplotlib/tests/test_imshow_lognorm_huge_range.py
@@ -0,0 +1,27 @@
+import numpy as np
+import pytest
+import matplotlib.pyplot as plt
+import matplotlib.colors as colors
+
+
+def test_imshow_lognorm_huge_range_no_error():
+    """
+    Test that imshow with LogNorm and data with a huge range does not
+    raise a ValueError.
+
+    This is a regression test for a bug where floating point inaccuracies
+    during internal rescaling could lead to a vmin of 0 for the LogNorm,
+    causing a "ValueError: Invalid vmin or vmax".
+    """
+    data = np.full((5, 5), -1, dtype=np.float64)
+    data[0:2, :] = 1E20
+
+    fig, ax = plt.subplots()
+    # LogNorm is created with valid vmin/vmax. The error occurs during the
+    # draw call inside `_make_image` where these are temporarily modified.
+    ax.imshow(data, norm=colors.LogNorm(vmin=100, vmax=data.max()),
+              interpolation='nearest', cmap='viridis')
+
+    # This call would raise "ValueError: Invalid vmin or vmax" with the bug.
+    # The test passes if it completes without raising an exception.
+    fig.canvas.draw()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/image\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_imshow_lognorm_huge_range.py
cat coverage.cover
git checkout b7ce415c15eb39b026a097a2865da73fbcf15c9c
git apply /root/pre_state.patch
