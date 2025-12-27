#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7fdf772201e4c9bafbc16dfac23b5472d6a53fa2 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7fdf772201e4c9bafbc16dfac23b5472d6a53fa2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_colormap.py b/lib/matplotlib/tests/test_colormap.py
new file mode 100644
index 0000000000..c2e9e440d4
--- /dev/null
+++ b/lib/matplotlib/tests/test_colormap.py
@@ -0,0 +1,58 @@
+import pytest
+import matplotlib as mpl
+import matplotlib.pyplot as plt
+from matplotlib import cm
+from matplotlib.colors import LinearSegmentedColormap
+import numpy as np
+
+
+def test_colormap_registration_name_clash_fails():
+    """
+    This test demonstrates a bug where registering a colormap with a name
+    different from its internal `name` attribute causes `imshow` to fail.
+
+    The test is expected to FAIL with a `ValueError` until the bug is fixed.
+    By failing, it correctly reproduces and highlights the bug.
+
+    See issue #4462.
+    """
+    my_cmap_data = [[1.5e-03, 4.7e-04, 1.4e-02],
+                    [2.3e-03, 1.3e-03, 1.8e-02],
+                    [3.3e-03, 2.3e-03, 2.4e-02]]
+    # Create a colormap with an internal name 'some_cmap_name'
+    my_cmap = LinearSegmentedColormap.from_list(
+        'some_cmap_name', my_cmap_data)
+
+    # Register the colormap with a *different* public name
+    registered_name = 'my_cmap_name'
+
+    # Use a try/finally to ensure cleanup even if the test fails
+    try:
+        with pytest.warns(
+                mpl.MatplotlibDeprecationWarning,
+                match=r"matplotlib\.colormaps\.register\(name\)"
+        ):
+            cm.register_cmap(name=registered_name, cmap=my_cmap)
+
+        # Set the default colormap for plotting
+        plt.set_cmap(registered_name)
+
+        # This call to imshow is expected to fail with a ValueError due to the bug.
+        # The test does not catch the exception, so the test itself will fail.
+        fig, ax = plt.subplots()
+        im = ax.imshow([[1, 1], [2, 2]])
+
+        # This assertion will only be reached if the bug is fixed.
+        # It checks that the image is using the correct colormap object.
+        assert im.get_cmap() is my_cmap
+
+    finally:
+        # Cleanup: unregister the colormap and close the figure
+        with pytest.warns(
+                mpl.MatplotlibDeprecationWarning,
+                match=r"matplotlib\.colormaps\.unregister\(name\)"
+        ):
+            cm.unregister_cmap(registered_name)
+        plt.close('all')
+        # Restore rcParams to default to avoid side-effects
+        mpl.rcdefaults()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/cm\.py|lib/matplotlib/colors\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_colormap.py
cat coverage.cover
git checkout 7fdf772201e4c9bafbc16dfac23b5472d6a53fa2
git apply /root/pre_state.patch
