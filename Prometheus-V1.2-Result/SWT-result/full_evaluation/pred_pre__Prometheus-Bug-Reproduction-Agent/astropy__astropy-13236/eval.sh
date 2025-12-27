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
diff --git a/astropy/table/tests/test_structured_array.py b/astropy/table/tests/test_structured_array.py
new file mode 100644
index 0000000000..a015f1b688
--- /dev/null
+++ b/astropy/table/tests/test_structured_array.py
@@ -0,0 +1,25 @@
+# -*- coding: utf-8 -*-
+# Licensed under a 3-clause BSD style license - see LICENSE.rst
+
+import numpy as np
+import pytest
+
+from astropy.table import Column, NdarrayMixin, Table
+
+
+def test_structured_array_becomes_column():
+    """
+    Test that a structured array added to a Table becomes a Column.
+
+    Currently, it is transformed into a bare NdarrayMixin instance, which
+    is a deprecated behavior. This test will fail until the deprecation
+    cycle is complete. See #13186.
+    """
+    structured_array = np.array([(1, 'a'), (2, 'b')],
+                                dtype=[('f0', '<i4'), ('f1', '<U1')])
+
+    t = Table([structured_array], names=['a'])
+
+    # This fails now, as type(t['a']) is NdarrayMixin.
+    # It will pass when the auto-transform is removed and it becomes a Column.
+    assert type(t['a']) is Column

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/table/table\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/table/tests/test_structured_array.py
cat coverage.cover
git checkout 6ed769d58d89380ebaa1ef52b300691eefda8928
git apply /root/pre_state.patch
