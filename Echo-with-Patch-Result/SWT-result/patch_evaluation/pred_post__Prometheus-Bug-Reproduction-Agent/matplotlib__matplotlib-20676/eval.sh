#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6786f437df54ca7780a047203cbcfaa1db8dc542 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6786f437df54ca7780a047203cbcfaa1db8dc542
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/widgets.py b/lib/matplotlib/widgets.py
--- a/lib/matplotlib/widgets.py
+++ b/lib/matplotlib/widgets.py
@@ -2156,7 +2156,12 @@ def new_axes(self, ax):
             self.artists.append(self._rect)
 
     def _setup_edge_handle(self, props):
-        self._edge_handles = ToolLineHandles(self.ax, self.extents,
+        # Define initial position using the axis bounds to keep the same bounds
+        if self.direction == 'horizontal':
+            positions = self.ax.get_xbound()
+        else:
+            positions = self.ax.get_ybound()
+        self._edge_handles = ToolLineHandles(self.ax, positions,
                                              direction=self.direction,
                                              line_props=props,
                                              useblit=self.useblit)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_span_selector_limits.py b/lib/matplotlib/tests/test_span_selector_limits.py
new file mode 100644
index 0000000000..e00410d5f1
--- /dev/null
+++ b/lib/matplotlib/tests/test_span_selector_limits.py
@@ -0,0 +1,21 @@
+import pytest
+from matplotlib import pyplot as plt
+from matplotlib.widgets import SpanSelector
+from numpy.testing import assert_allclose
+
+
+def test_interactive_span_selector_limits():
+    """
+    Check that an interactive span selector does not change the axes limits.
+
+    See https://github.com/matplotlib/matplotlib/issues/21933
+    """
+    fig, ax = plt.subplots()
+    ax.plot([10, 20], [10, 20])
+    fig.canvas.draw()
+
+    xlim = ax.get_xlim()
+
+    SpanSelector(ax, lambda *args: None, "horizontal", interactive=True)
+
+    assert_allclose(ax.get_xlim(), xlim)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/widgets\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_span_selector_limits.py
cat coverage.cover
git checkout 6786f437df54ca7780a047203cbcfaa1db8dc542
git apply /root/pre_state.patch
