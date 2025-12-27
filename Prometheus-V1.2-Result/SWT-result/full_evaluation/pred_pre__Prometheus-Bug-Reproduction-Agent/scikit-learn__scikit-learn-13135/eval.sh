#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a061ada48efccf0845acae17009553e01764452b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a061ada48efccf0845acae17009553e01764452b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/preprocessing/tests/test_kbins_discretizer_bug.py b/sklearn/preprocessing/tests/test_kbins_discretizer_bug.py
new file mode 100644
index 0000000000..ded29523c2
--- /dev/null
+++ b/sklearn/preprocessing/tests/test_kbins_discretizer_bug.py
@@ -0,0 +1,19 @@
+import numpy as np
+import pytest
+
+from sklearn.preprocessing import KBinsDiscretizer
+from sklearn.utils.testing import assert_array_equal
+
+
+def test_kmeans_discretizer_unsorted_bins():
+    """Test for bug #13684.
+
+    KBinsDiscretizer with strategy='kmeans' should not fail with unsorted
+    bin edges.
+    """
+    X = np.array([0, 0.5, 2, 3, 9, 10]).reshape(-1, 1)
+
+    # with 5 bins
+    est = KBinsDiscretizer(n_bins=5, strategy='kmeans', encode='ordinal')
+    # This line should not raise a ValueError
+    est.fit_transform(X)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/preprocessing/_discretization\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/preprocessing/tests/test_kbins_discretizer_bug.py
cat coverage.cover
git checkout a061ada48efccf0845acae17009553e01764452b
git apply /root/pre_state.patch
