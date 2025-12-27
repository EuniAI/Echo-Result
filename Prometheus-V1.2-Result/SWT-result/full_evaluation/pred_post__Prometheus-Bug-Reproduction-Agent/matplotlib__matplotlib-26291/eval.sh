#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fa68f46289adf4a8a4bc7ba97ded8258ec9d079c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fa68f46289adf4a8a4bc7ba97ded8258ec9d079c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/mpl_toolkits/axes_grid1/inset_locator.py b/lib/mpl_toolkits/axes_grid1/inset_locator.py
--- a/lib/mpl_toolkits/axes_grid1/inset_locator.py
+++ b/lib/mpl_toolkits/axes_grid1/inset_locator.py
@@ -69,6 +69,8 @@ def draw(self, renderer):
         raise RuntimeError("No draw method should be called")
 
     def __call__(self, ax, renderer):
+        if renderer is None:
+            renderer = ax.figure._get_renderer()
         self.axes = ax
         bbox = self.get_window_extent(renderer)
         px, py = self.get_offset(bbox.width, bbox.height, 0, 0, renderer)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/mpl_toolkits/axes_grid1/tests/test_inset_locator.py b/lib/mpl_toolkits/axes_grid1/tests/test_inset_locator.py
new file mode 100644
index 0000000000..71535615d7
--- /dev/null
+++ b/lib/mpl_toolkits/axes_grid1/tests/test_inset_locator.py
@@ -0,0 +1,23 @@
+import io
+import matplotlib.pyplot as plt
+from mpl_toolkits.axes_grid1.inset_locator import inset_axes
+
+
+def test_inset_axes_savefig_tight_bbox_error():
+    """
+    Test for AttributeError with inset_axes when saving with tight bbox.
+
+    This test reproduces the bug where saving a figure with an inset axes
+    and `bbox_inches='tight'` raises an `AttributeError`. The error is
+    triggered during the tight bounding box calculation because the inset
+    axes locator is not properly associated with a figure, leading to
+    `self.figure` being `None`.
+    """
+    fig, (ax, ax2) = plt.subplots(1, 2, figsize=[5.5, 2.8])
+    inset_axes(ax, width=1.3, height=0.9)
+
+    # The bug is triggered by saving with bbox_inches='tight', which fails
+    # with an AttributeError: 'NoneType' object has no attribute '_get_renderer'.
+    # This test will fail before the fix and pass after. No explicit assert
+    # is needed as the test will fail if any exception is raised.
+    fig.savefig(io.BytesIO(), bbox_inches='tight')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/mpl_toolkits/axes_grid1/inset_locator\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/mpl_toolkits/axes_grid1/tests/test_inset_locator.py
cat coverage.cover
git checkout fa68f46289adf4a8a4bc7ba97ded8258ec9d079c
git apply /root/pre_state.patch
