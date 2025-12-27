#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6ed769d58d89380ebaa1ef52b300691eefda8928 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6ed769d58d89380ebaa1ef52b300691eefda8928
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/table/tests/test_structured_array_ndmixin_deprecation.py b/astropy/table/tests/test_structured_array_ndmixin_deprecation.py
new file mode 100644
index 0000000000..645b0fc990
--- /dev/null
+++ b/astropy/table/tests/test_structured_array_ndmixin_deprecation.py
@@ -0,0 +1,19 @@
+import pytest
+import numpy as np
+
+from astropy.table import Table, NdarrayMixin
+
+
+def test_structured_array_ndmixin_deprecation():
+    """
+    Test that adding a structured array to a Table without wrapping in Column
+    gives a FutureWarning, as per the deprecation described in #12973.
+    """
+    struct_array = np.array([(1, 'a'), (2, 'b')], dtype=[('i', int), ('s', 'S1')])
+
+    with pytest.warns(FutureWarning, match='Adding a structured numpy.ndarray as a Table column'):
+        t = Table([struct_array])
+
+    # The minimal assertion is that the warning is raised.
+    # For completeness, we also check that for now, it is still converted to NdarrayMixin.
+    assert isinstance(t['col0'], NdarrayMixin)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/table/table\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/table/tests/test_structured_array_ndmixin_deprecation.py
cat coverage.cover
git checkout 6ed769d58d89380ebaa1ef52b300691eefda8928
git apply /root/pre_state.patch
