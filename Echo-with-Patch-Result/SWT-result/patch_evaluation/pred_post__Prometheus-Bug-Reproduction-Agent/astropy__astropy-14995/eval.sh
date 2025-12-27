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
diff --git a/astropy/nddata/mixins/ndarithmetic.py b/astropy/nddata/mixins/ndarithmetic.py
--- a/astropy/nddata/mixins/ndarithmetic.py
+++ b/astropy/nddata/mixins/ndarithmetic.py
@@ -520,10 +520,10 @@ def _arithmetic_mask(self, operation, operand, handle_mask, axis=None, **kwds):
         elif self.mask is None and operand is not None:
             # Make a copy so there is no reference in the result.
             return deepcopy(operand.mask)
-        elif operand is None:
+        elif operand.mask is None:
             return deepcopy(self.mask)
         else:
-            # Now lets calculate the resulting mask (operation enforces copy)
+            # Now let's calculate the resulting mask (operation enforces copy)
             return handle_mask(self.mask, operand.mask, **kwds)
 
     def _arithmetic_wcs(self, operation, operand, compare_wcs, **kwds):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/nddata/tests/test_nddata_masking.py b/astropy/nddata/tests/test_nddata_masking.py
new file mode 100644
index 0000000000..387cbb26df
--- /dev/null
+++ b/astropy/nddata/tests/test_nddata_masking.py
@@ -0,0 +1,44 @@
+import numpy as np
+import pytest
+from numpy.testing import assert_array_equal
+
+from astropy.nddata import NDDataRef
+
+
+def test_bitwise_or_mask_propagation_with_one_missing():
+    """
+    Test that bitwise_or mask propagation works when one operand has no mask.
+
+    Regression test for https://github.com/astropy/astropy/issues/15269.
+    """
+    array = np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]])
+    mask = np.array([[0, 1, 64], [8, 0, 1], [2, 1, 0]])
+
+    nref_nomask = NDDataRef(array)
+    nref_mask = NDDataRef(array, mask=mask)
+
+    # This operation failed because the operand without a mask was treated as
+    # having a mask of None, which cannot be used in a bitwise-or.
+    result = nref_mask.multiply(nref_nomask, handle_mask=np.bitwise_or)
+
+    # The mask of the result should be identical to the input mask.
+    assert_array_equal(result.mask, mask)
+
+
+def test_bitwise_or_mask_propagation_with_scalar():
+    """
+    Test that bitwise_or mask propagation works when one operand is a scalar.
+
+    Regression test for https://github.com/astropy/astropy/issues/15269.
+    """
+    array = np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]])
+    mask = np.array([[0, 1, 64], [8, 0, 1], [2, 1, 0]])
+
+    nref_mask = NDDataRef(array, mask=mask)
+
+    # This operation failed because the scalar operand was treated as having a
+    # mask of None, which cannot be used in a bitwise-or with the nddata's mask.
+    result = nref_mask.multiply(1.0, handle_mask=np.bitwise_or)
+
+    # The mask of the result should be identical to the input mask.
+    assert_array_equal(result.mask, mask)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/nddata/mixins/ndarithmetic\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/nddata/tests/test_nddata_masking.py
cat coverage.cover
git checkout b16c7d12ccbc7b2d20364b89fb44285bcbfede54
git apply /root/pre_state.patch
