#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 8f0003ae902952372824c9917975fb372c026a42 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 8f0003ae902952372824c9917975fb372c026a42
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_hpacker_alignment.py b/lib/matplotlib/tests/test_hpacker_alignment.py
new file mode 100644
index 0000000000..6a99f7c6e4
--- /dev/null
+++ b/lib/matplotlib/tests/test_hpacker_alignment.py
@@ -0,0 +1,33 @@
+import pytest
+import matplotlib.pyplot as plt
+from matplotlib.offsetbox import DrawingArea, HPacker
+
+
+def test_hpacker_align_reversed():
+    """
+    Test that HPacker alignment for 'top' and 'bottom' is correct.
+
+    The bug described in the issue shows that the behavior of 'top' and
+    'bottom' alignment in HPacker is reversed. This test asserts the
+    expected, correct behavior. It will fail with the buggy implementation
+    and pass once the logic is corrected.
+    """
+    # A renderer is needed to calculate the layout.
+    fig, ax = plt.subplots()
+    renderer = fig.canvas.get_renderer()
+
+    # Create two children of different heights to test alignment.
+    da1 = DrawingArea(10, 20)  # height=20
+    da2 = DrawingArea(10, 30)  # height=30
+
+    # Pack the children using HPacker with 'bottom' alignment.
+    packer = HPacker(children=[da1, da2], align="bottom", pad=0, sep=0)
+
+    # get_extent_offsets calculates the final positions of the children.
+    *_, offsets = packer.get_extent_offsets(renderer)
+    y_offsets = [y for x, y in offsets]
+
+    # For correct 'bottom' alignment, the y-offsets should be the same
+    # (0, as they share a baseline). The buggy code implements 'top'
+    # alignment instead, giving y-offsets of [10., 0.].
+    assert y_offsets == [0., 0.]

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/offsetbox\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_hpacker_alignment.py
cat coverage.cover
git checkout 8f0003ae902952372824c9917975fb372c026a42
git apply /root/pre_state.patch
