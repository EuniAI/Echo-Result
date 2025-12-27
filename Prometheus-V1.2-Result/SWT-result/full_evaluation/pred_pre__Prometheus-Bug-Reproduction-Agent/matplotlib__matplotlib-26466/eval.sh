#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3dd06a46750d174f821df5377996f493f1af4ebb >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3dd06a46750d174f821df5377996f493f1af4ebb
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_annotation.py b/lib/matplotlib/tests/test_annotation.py
new file mode 100644
index 0000000000..42a1b7f43a
--- /dev/null
+++ b/lib/matplotlib/tests/test_annotation.py
@@ -0,0 +1,24 @@
+import numpy as np
+import pytest
+import matplotlib.pyplot as plt
+
+
+def test_annotation_xy_mutability():
+    """
+    Test that updating an array passed as the `xy` parameter to `annotate`
+    does not update the annotation. The Annotation object should store a copy
+    of the xy array.
+    """
+    fig, ax = plt.subplots()
+
+    xy_pos = np.array([1, 1], dtype=float)
+    ann = ax.annotate('test', xy=xy_pos, xytext=(0, 0),
+                      arrowprops=dict(arrowstyle="->"))
+
+    # Mutating the array passed to `xy` should not affect the annotation.
+    xy_pos[0] = 2
+
+    # The bug is that `ann.xy` is a reference to `xy_pos`, so it gets
+    # modified. This assertion will fail. After the fix, `annotate` will
+    # make a copy, and this assertion will pass.
+    assert ann.xy[0] == 1

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/text\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_annotation.py
cat coverage.cover
git checkout 3dd06a46750d174f821df5377996f493f1af4ebb
git apply /root/pre_state.patch
