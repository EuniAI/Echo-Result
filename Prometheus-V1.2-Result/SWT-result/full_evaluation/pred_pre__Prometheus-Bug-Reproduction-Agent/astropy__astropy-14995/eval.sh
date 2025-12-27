#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b16c7d12ccbc7b2d20364b89fb44285bcbfede54 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b16c7d12ccbc7b2d20364b89fb44285bcbfede54
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/nddata/tests/test_regression.py b/astropy/nddata/tests/test_regression.py
new file mode 100644
index 0000000000..b6e7cbccad
--- /dev/null
+++ b/astropy/nddata/tests/test_regression.py
@@ -0,0 +1,24 @@
+import numpy as np
+import pytest
+from numpy.testing import assert_array_equal
+
+from astropy.nddata import NDDataRef
+
+
+def test_bitwise_or_mask_propagation_with_no_mask_operand():
+    """
+    Regression test for a bug where mask propagation with `np.bitwise_or`
+    failed if one of the operands did not have a mask.
+
+    See https://github.com/astropy/astropy/issues/15166
+    """
+    array = np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]])
+    mask = np.array([[0, 1, 64], [8, 0, 1], [2, 1, 0]])
+
+    nref_mask = NDDataRef(array, mask=mask)
+    nref_nomask = NDDataRef(array)
+
+    # This failed when multiplying an NDDataRef with a mask by another
+    # NDDataRef that has no mask, and a function handle for the mask.
+    result = nref_mask.multiply(nref_nomask, handle_mask=np.bitwise_or)
+    assert_array_equal(result.mask, mask)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/nddata/mixins/ndarithmetic\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/nddata/tests/test_regression.py
cat coverage.cover
git checkout b16c7d12ccbc7b2d20364b89fb44285bcbfede54
git apply /root/pre_state.patch
