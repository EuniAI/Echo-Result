#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2aee6ccd7c7e1f8d282c1e7579f4ee546b838542 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2aee6ccd7c7e1f8d282c1e7579f4ee546b838542
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/collections.py b/lib/matplotlib/collections.py
--- a/lib/matplotlib/collections.py
+++ b/lib/matplotlib/collections.py
@@ -207,7 +207,8 @@ def get_paths(self):
         return self._paths
 
     def set_paths(self, paths):
-        raise NotImplementedError
+        self._paths = paths
+        self.stale = True
 
     def get_transforms(self):
         return self._transforms
@@ -1001,10 +1002,6 @@ def __init__(self, paths, sizes=None, **kwargs):
         self.set_sizes(sizes)
         self.stale = True
 
-    def set_paths(self, paths):
-        self._paths = paths
-        self.stale = True
-
     def get_paths(self):
         return self._paths
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_contour_set.py b/lib/matplotlib/tests/test_contour_set.py
new file mode 100644
index 0000000000..000fd94198
--- /dev/null
+++ b/lib/matplotlib/tests/test_contour_set.py
@@ -0,0 +1,15 @@
+import numpy as np
+import pytest
+from matplotlib import pyplot as plt
+from matplotlib.path import Path
+
+
+def test_set_paths():
+    """Test ContourSet.set_paths()."""
+    fig, ax = plt.subplots()
+    cs = ax.contour([[0, 1], [2, 3]])
+
+    new_paths = [Path(np.array([[0., 0.], [1., 1.]]))]
+    cs.set_paths(new_paths)
+
+    assert cs.get_paths() == new_paths

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/collections\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_contour_set.py
cat coverage.cover
git checkout 2aee6ccd7c7e1f8d282c1e7579f4ee546b838542
git apply /root/pre_state.patch
