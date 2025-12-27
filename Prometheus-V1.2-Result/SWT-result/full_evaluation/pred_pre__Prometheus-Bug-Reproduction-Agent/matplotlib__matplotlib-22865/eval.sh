#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c6c7ec1978c22ae2c704555a873d0ec6e1e2eaa8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c6c7ec1978c22ae2c704555a873d0ec6e1e2eaa8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_colorbar_drawedges_extended.py b/lib/matplotlib/tests/test_colorbar_drawedges_extended.py
new file mode 100644
index 0000000000..bbb935892c
--- /dev/null
+++ b/lib/matplotlib/tests/test_colorbar_drawedges_extended.py
@@ -0,0 +1,28 @@
+import matplotlib as mpl
+import numpy as np
+import matplotlib.pyplot as plt
+from matplotlib.colors import from_levels_and_colors
+
+
+def test_colorbar_drawedges_extended():
+    """
+    Test that for a colorbar with drawedges=True and extend='both',
+    the extension patches have a visible linewidth.
+
+    Based on https://github.com/matplotlib/matplotlib/issues/22849
+    """
+    my_cmap = mpl.cm.viridis
+    bounds = np.arange(10)
+    nb_colors = len(bounds) + 1
+    colors = my_cmap(np.linspace(100, 255, nb_colors).astype(int))
+    my_cmap, my_norm = from_levels_and_colors(bounds, colors, extend='both')
+
+    fig, ax = plt.subplots()
+    cbar = mpl.colorbar.ColorbarBase(ax, cmap=my_cmap, norm=my_norm,
+                                     orientation='horizontal', drawedges=True)
+
+    # The bug is that the edges of the extension patches are not drawn.
+    # This is likely because their linewidth is 0. This assertion will fail
+    # if the bug is present and pass when it is fixed.
+    for patch in cbar._extend_patches:
+        assert patch.get_linewidth() > 0

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/colorbar\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_colorbar_drawedges_extended.py
cat coverage.cover
git checkout c6c7ec1978c22ae2c704555a873d0ec6e1e2eaa8
git apply /root/pre_state.patch
