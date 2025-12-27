#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f06c2c3abdaf4b90285ce5ca7fedbb8ace715911 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f06c2c3abdaf4b90285ce5ca7fedbb8ace715911
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/patches.py b/lib/matplotlib/patches.py
--- a/lib/matplotlib/patches.py
+++ b/lib/matplotlib/patches.py
@@ -586,9 +586,8 @@ def draw(self, renderer):
         # docstring inherited
         if not self.get_visible():
             return
-        # Patch has traditionally ignored the dashoffset.
-        with cbook._setattr_cm(
-                 self, _dash_pattern=(0, self._dash_pattern[1])), \
+
+        with cbook._setattr_cm(self, _dash_pattern=(self._dash_pattern)), \
              self._bind_draw_path_function(renderer) as draw_path:
             path = self.get_path()
             transform = self.get_transform()

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_patch_dash_offset.py b/lib/matplotlib/tests/test_patch_dash_offset.py
new file mode 100644
index 0000000000..4945dbb3a6
--- /dev/null
+++ b/lib/matplotlib/tests/test_patch_dash_offset.py
@@ -0,0 +1,44 @@
+import pytest
+import matplotlib.patches as mpatches
+import matplotlib.lines as mlines
+from matplotlib.testing.decorators import check_figures_equal
+
+
+@check_figures_equal()
+def test_patch_dash_offset(fig_test, fig_ref):
+    """
+    Test that the dash offset for patches is honored.
+
+    A patch with a given dash style is compared to a line with the same
+    style. The line is known to render correctly.
+    """
+    # Use a zero-height rectangle to easily compare with a line.
+    ls = (10, (10, 10))
+    lw = 4
+
+    # Test figure with the patch (currently buggy)
+    ax_test = fig_test.add_subplot()
+    ax_test.add_patch(
+        mpatches.Rectangle(
+            (0.1, 0.5), 0.8, 0,
+            linewidth=lw,
+            linestyle=ls,
+            edgecolor='b',
+            facecolor='none'
+        )
+    )
+    ax_test.set_xlim(0, 1)
+    ax_test.set_ylim(0, 1)
+
+    # Reference figure with a line (correct rendering)
+    ax_ref = fig_ref.add_subplot()
+    ax_ref.add_line(
+        mlines.Line2D(
+            [0.1, 0.9], [0.5, 0.5],
+            linewidth=lw,
+            linestyle=ls,
+            color='b'
+        )
+    )
+    ax_ref.set_xlim(0, 1)
+    ax_ref.set_ylim(0, 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/patches\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_patch_dash_offset.py
cat coverage.cover
git checkout f06c2c3abdaf4b90285ce5ca7fedbb8ace715911
git apply /root/pre_state.patch
