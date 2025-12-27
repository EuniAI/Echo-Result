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
diff --git a/lib/matplotlib/tests/test_shared_axes_clear.py b/lib/matplotlib/tests/test_shared_axes_clear.py
new file mode 100644
index 0000000000..a530c8f2c9
--- /dev/null
+++ b/lib/matplotlib/tests/test_shared_axes_clear.py
@@ -0,0 +1,27 @@
+import pytest
+import numpy as np
+import matplotlib.pyplot as plt
+
+
+def test_clear_shared_axes_tick_labels():
+    """
+    Test that ax.clear() does not show tick labels that should be hidden.
+
+    This is a regression test based on a bug report where calling `ax.clear()`
+    on a shared-axis subplot would cause tick labels to reappear incorrectly.
+    """
+    fig, axes = plt.subplots(2, 2, sharex=True, sharey=True)
+
+    x = np.arange(0.0, 2 * np.pi, 0.01)
+    y = np.sin(x)
+
+    for ax in axes.flatten():
+        ax.clear()
+        ax.plot(x, y)
+
+    # For a 2x2 grid with sharex=True, the x-tick labels on the top row
+    # of axes should not be visible. This assertion checks the top-left axis.
+    # The bug causes these labels to become visible after ax.clear(),
+    # so this assertion will fail.
+    assert all(not label.get_visible() for label
+               in axes[0, 0].get_xticklabels())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/axis\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_shared_axes_clear.py
cat coverage.cover
git checkout a0d2e399729d36499a1924e5ca5bc067c8396810
git apply /root/pre_state.patch
