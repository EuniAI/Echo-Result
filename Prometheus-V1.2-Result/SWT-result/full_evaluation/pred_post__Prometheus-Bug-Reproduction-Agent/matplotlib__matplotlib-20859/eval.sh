#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 64619e53e9d0ed417daba287ac0d3a06943a54d5 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 64619e53e9d0ed417daba287ac0d3a06943a54d5
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/legend.py b/lib/matplotlib/legend.py
--- a/lib/matplotlib/legend.py
+++ b/lib/matplotlib/legend.py
@@ -360,7 +360,7 @@ def __init__(
         """
         # local import only to avoid circularity
         from matplotlib.axes import Axes
-        from matplotlib.figure import Figure
+        from matplotlib.figure import FigureBase
 
         super().__init__()
 
@@ -434,11 +434,13 @@ def __init__(
             self.isaxes = True
             self.axes = parent
             self.set_figure(parent.figure)
-        elif isinstance(parent, Figure):
+        elif isinstance(parent, FigureBase):
             self.isaxes = False
             self.set_figure(parent)
         else:
-            raise TypeError("Legend needs either Axes or Figure as parent")
+            raise TypeError(
+                "Legend needs either Axes or FigureBase as parent"
+            )
         self.parent = parent
 
         self._loc_used_default = loc is None

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_subfigure.py b/lib/matplotlib/tests/test_subfigure.py
new file mode 100644
index 0000000000..68ea82fc43
--- /dev/null
+++ b/lib/matplotlib/tests/test_subfigure.py
@@ -0,0 +1,17 @@
+import matplotlib.pyplot as plt
+import pytest
+
+
+def test_subfigure_legend():
+    """
+    Test that adding a legend to a SubFigure works.
+
+    This test reproduces the bug where calling legend() on a SubFigure instance
+    raises a TypeError. The expected behavior is for a legend to be created
+    on the subfigure. The test will pass when the bug is fixed.
+    """
+    subfig = plt.figure().subfigures()
+    ax = subfig.subplots()
+    ax.plot([0, 1, 2], [0, 1, 2], label="test")
+    subfig.legend()
+    assert len(subfig.legends) == 1

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/legend\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_subfigure.py
cat coverage.cover
git checkout 64619e53e9d0ed417daba287ac0d3a06943a54d5
git apply /root/pre_state.patch
