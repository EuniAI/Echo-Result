#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 10dbc142bd17ccf7bd38eec2ac04b52ce0d1009e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 10dbc142bd17ccf7bd38eec2ac04b52ce0d1009e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/feature_selection/tests/test_sfs_cv_iterator.py b/sklearn/feature_selection/tests/test_sfs_cv_iterator.py
new file mode 100644
index 0000000000..eca341149f
--- /dev/null
+++ b/sklearn/feature_selection/tests/test_sfs_cv_iterator.py
@@ -0,0 +1,34 @@
+import pytest
+import numpy as np
+
+from sklearn.datasets import make_classification
+from sklearn.feature_selection import SequentialFeatureSelector
+from sklearn.neighbors import KNeighborsClassifier
+from sklearn.model_selection import LeaveOneGroupOut
+
+
+def test_sfs_cv_iterator():
+    """Test that SFS works with a cv iterator.
+
+    Non-regression test for #25959.
+    """
+    X, y = make_classification(
+        n_samples=100, n_features=10, n_informative=3, random_state=0
+    )
+
+    groups = np.zeros_like(y, dtype=int)
+    groups[y.size // 2 :] = 1
+
+    cv = LeaveOneGroupOut()
+    splits = cv.split(X, y, groups=groups)
+
+    clf = KNeighborsClassifier(n_neighbors=5)
+    n_features_to_select = 5
+
+    sfs = SequentialFeatureSelector(
+        clf, n_features_to_select=n_features_to_select, scoring="accuracy", cv=splits
+    )
+    # This call should not raise an IndexError
+    sfs.fit(X, y)
+
+    assert sfs.n_features_to_select_ == n_features_to_select

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/feature_selection/_sequential\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/feature_selection/tests/test_sfs_cv_iterator.py
cat coverage.cover
git checkout 10dbc142bd17ccf7bd38eec2ac04b52ce0d1009e
git apply /root/pre_state.patch
