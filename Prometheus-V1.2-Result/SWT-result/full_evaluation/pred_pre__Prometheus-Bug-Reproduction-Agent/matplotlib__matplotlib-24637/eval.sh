#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a9ba9d5d3fe9d5ac15fbdb06127f97d381148dd0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a9ba9d5d3fe9d5ac15fbdb06127f97d381148dd0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_annotation_bbox.py b/lib/matplotlib/tests/test_annotation_bbox.py
new file mode 100644
index 0000000000..fbe7bfdcfb
--- /dev/null
+++ b/lib/matplotlib/tests/test_annotation_bbox.py
@@ -0,0 +1,34 @@
+# E501 is a too-long line, which is okay in test data.
+# ruff: noqa: E501
+
+import pytest
+from io import BytesIO
+
+import numpy as np
+
+import matplotlib.pyplot as plt
+from matplotlib.offsetbox import (OffsetImage, AnnotationBbox)
+
+
+def test_annotation_bbox_gid():
+    """Test that AnnotationBbox gid is passed to the renderer."""
+    fig, ax = plt.subplots()
+
+    # Create a dummy image
+    arr_img = np.zeros((10, 10))
+
+    # Create the AnnotationBbox
+    imagebox = OffsetImage(arr_img, zoom=0.1)
+    ab = AnnotationBbox(imagebox, (0.5, 0.5),
+                        xycoords='data',
+                        pad=0)
+    ab.set_gid('my_annotation_gid')
+    ax.add_artist(ab)
+
+    # Save to SVG
+    with BytesIO() as buf:
+        fig.savefig(buf, format="svg")
+        svg = buf.getvalue().decode('utf-8')
+
+    # Check that the gid is present in the SVG output
+    assert 'id="my_annotation_gid"' in svg
\ No newline at end of file

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/offsetbox\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_annotation_bbox.py
cat coverage.cover
git checkout a9ba9d5d3fe9d5ac15fbdb06127f97d381148dd0
git apply /root/pre_state.patch
