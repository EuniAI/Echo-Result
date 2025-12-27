#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a3011dfd1aaa2487cce8aa7369475533133ef777 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a3011dfd1aaa2487cce8aa7369475533133ef777
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/colors.py b/lib/matplotlib/colors.py
--- a/lib/matplotlib/colors.py
+++ b/lib/matplotlib/colors.py
@@ -715,16 +715,17 @@ def __call__(self, X, alpha=None, bytes=False):
         if not xa.dtype.isnative:
             xa = xa.byteswap().newbyteorder()  # Native byteorder is faster.
         if xa.dtype.kind == "f":
-            with np.errstate(invalid="ignore"):
-                xa *= self.N
-                # Negative values are out of range, but astype(int) would
-                # truncate them towards zero.
-                xa[xa < 0] = -1
-                # xa == 1 (== N after multiplication) is not out of range.
-                xa[xa == self.N] = self.N - 1
-                # Avoid converting large positive values to negative integers.
-                np.clip(xa, -1, self.N, out=xa)
-                xa = xa.astype(int)
+            xa *= self.N
+            # Negative values are out of range, but astype(int) would
+            # truncate them towards zero.
+            xa[xa < 0] = -1
+            # xa == 1 (== N after multiplication) is not out of range.
+            xa[xa == self.N] = self.N - 1
+            # Avoid converting large positive values to negative integers.
+            np.clip(xa, -1, self.N, out=xa)
+        with np.errstate(invalid="ignore"):
+            # We need this cast for unsigned ints as well as floats
+            xa = xa.astype(int)
         # Set the over-range indices before the under-range;
         # otherwise the under-range values get converted to over-range.
         xa[xa > self.N - 1] = self._i_over

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_numpy_deprecation.py b/lib/matplotlib/tests/test_numpy_deprecation.py
new file mode 100644
index 0000000000..ee3605b2a2
--- /dev/null
+++ b/lib/matplotlib/tests/test_numpy_deprecation.py
@@ -0,0 +1,24 @@
+import pytest
+import matplotlib.pyplot as plt
+import numpy as np
+
+
+def test_no_numpy_deprecation_with_empty_array(recwarn):
+    """
+    Test for NumPy 1.24 deprecation warnings when applying a colormap to an
+    empty array.
+
+    The test fails if the specific DeprecationWarning from NumPy is raised,
+    which is the bug's behavior. When the bug is fixed, no warning will be
+    raised, and the test will pass.
+    """
+    # This line causes DeprecationWarnings with NumPy 1.24+
+    plt.get_cmap()(np.empty((0,), dtype=np.uint8))
+
+    # Filter for the specific deprecation warnings mentioned in the bug report.
+    numpy_warnings = [
+        w for w in recwarn
+        if (issubclass(w.category, DeprecationWarning) and
+            "NumPy will stop allowing conversion" in str(w.message))
+    ]
+    assert not numpy_warnings

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/colors\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_numpy_deprecation.py
cat coverage.cover
git checkout a3011dfd1aaa2487cce8aa7369475533133ef777
git apply /root/pre_state.patch
