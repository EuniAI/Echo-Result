#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a0d2e399729d36499a1924e5ca5bc067c8396810 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a0d2e399729d36499a1924e5ca5bc067c8396810
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_regression.py b/lib/matplotlib/tests/test_regression.py
new file mode 100644
index 0000000000..8ca2ef4a4f
--- /dev/null
+++ b/lib/matplotlib/tests/test_regression.py
@@ -0,0 +1,29 @@
+import numpy as np
+import matplotlib.pyplot as plt
+import pytest
+
+
+def test_clear_shared_axes_tick_visibility():
+    """
+    Test that ax.clear() does not un-hide shared-axis tick labels.
+
+    This is a regression test for a bug where calling ax.clear() on a
+    shared axis would reset the tick visibility, causing inner tick labels
+    to reappear.
+    """
+    fig, axes = plt.subplots(2, 2, sharex=True, sharey=True)
+
+    # The bug is triggered by calling clear() on the axes.
+    # We also plot something to ensure that ticks and labels are generated.
+    for ax in axes.flatten():
+        ax.clear()
+        ax.plot(np.arange(10))
+
+    # We must draw the canvas for the tick label visibility to be updated.
+    fig.canvas.draw()
+
+    # The top-left axes (axes[0, 0]) should not have visible x-tick labels
+    # because it shares its x-axis with the plot below it. The bug causes
+    # these labels to become visible. A minimal assertion checks this.
+    assert not any(label.get_visible()
+                   for label in axes[0, 0].get_xticklabels())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/axis\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_regression.py
cat coverage.cover
git checkout a0d2e399729d36499a1924e5ca5bc067c8396810
git apply /root/pre_state.patch
