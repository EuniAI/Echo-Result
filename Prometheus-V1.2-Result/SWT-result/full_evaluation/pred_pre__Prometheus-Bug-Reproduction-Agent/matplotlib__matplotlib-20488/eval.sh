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
