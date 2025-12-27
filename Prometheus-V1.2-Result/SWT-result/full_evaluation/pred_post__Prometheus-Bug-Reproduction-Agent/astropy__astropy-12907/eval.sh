#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d16bfe05a744909de4b27f5875fe0d4ed41ce607 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d16bfe05a744909de4b27f5875fe0d4ed41ce607
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/modeling/separable.py b/astropy/modeling/separable.py
--- a/astropy/modeling/separable.py
+++ b/astropy/modeling/separable.py
@@ -242,7 +242,7 @@ def _cstack(left, right):
         cright = _coord_matrix(right, 'right', noutp)
     else:
         cright = np.zeros((noutp, right.shape[1]))
-        cright[-right.shape[0]:, -right.shape[1]:] = 1
+        cright[-right.shape[0]:, -right.shape[1]:] = right
 
     return np.hstack([cleft, cright])
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/modeling/tests/test_regression.py b/astropy/modeling/tests/test_regression.py
new file mode 100644
index 0000000000..6de60bffc1
--- /dev/null
+++ b/astropy/modeling/tests/test_regression.py
@@ -0,0 +1,29 @@
+# Licensed under a 3-clause BSD style license - see LICENSE.rst
+"""
+Test separability of models.
+
+"""
+# pylint: disable=invalid-name
+import pytest
+import numpy as np
+from numpy.testing import assert_allclose
+
+from astropy.modeling import models
+from astropy.modeling.separable import separability_matrix
+
+
+def test_separability_matrix_for_nested_compound_models():
+    """
+    A regression test for a bug in `separability_matrix` that does not
+    compute separability correctly for nested CompoundModels.
+    """
+    cm = models.Linear1D(10) & models.Linear1D(5)
+    model = models.Pix2Sky_TAN() & cm
+    expected = np.array([
+        [True, True, False, False],
+        [True, True, False, False],
+        [False, False, True, False],
+        [False, False, False, True]
+    ])
+    result = separability_matrix(model)
+    assert_allclose(result, expected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/modeling/separable\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/modeling/tests/test_regression.py
cat coverage.cover
git checkout d16bfe05a744909de4b27f5875fe0d4ed41ce607
git apply /root/pre_state.patch
