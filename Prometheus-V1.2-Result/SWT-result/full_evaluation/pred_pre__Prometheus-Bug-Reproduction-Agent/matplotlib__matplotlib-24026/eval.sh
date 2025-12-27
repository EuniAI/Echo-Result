#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 14c96b510ebeba40f573e512299b1976f35b620e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 14c96b510ebeba40f573e512299b1976f35b620e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_stackplot.py b/lib/matplotlib/tests/test_stackplot.py
new file mode 100644
index 0000000000..1c24eaf8a8
--- /dev/null
+++ b/lib/matplotlib/tests/test_stackplot.py
@@ -0,0 +1,24 @@
+import pytest
+import numpy as np
+import matplotlib.pyplot as plt
+
+def test_stackplot_cn_color():
+    """
+    Test that stackplot can accept 'CN' color strings, which should be
+    resolved against the Axes property cycler.
+
+    This test reproduces the bug reported in issue #14221, where passing
+    'CN' strings to the `colors` argument of `stackplot` raises a ValueError
+    instead of using the cycler's colors.
+    """
+    fig, ax = plt.subplots()
+    x = [1, 2, 3]
+    y = np.array([[1, 1, 1], [1, 2, 3], [4, 3, 2]])
+
+    # This call raises a ValueError on the faulty code but should execute
+    # without error when fixed.
+    collections = ax.stackplot(x, y, colors=['C2', 'C3', 'C4'])
+
+    # A minimal assertion that will pass when the bug is fixed.
+    # stackplot should return one PolyCollection for each data series.
+    assert len(collections) == 3

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/stackplot\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_stackplot.py
cat coverage.cover
git checkout 14c96b510ebeba40f573e512299b1976f35b620e
git apply /root/pre_state.patch
