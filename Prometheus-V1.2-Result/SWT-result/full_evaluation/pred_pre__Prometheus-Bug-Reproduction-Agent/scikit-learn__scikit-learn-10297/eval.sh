#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b90661d6a46aa3619d3eec94d5281f5888add501 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b90661d6a46aa3619d3eec94d5281f5888add501
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/linear_model/tests/test_ridge_classifier_cv.py b/sklearn/linear_model/tests/test_ridge_classifier_cv.py
new file mode 100644
index 0000000000..cc5bd52c78
--- /dev/null
+++ b/sklearn/linear_model/tests/test_ridge_classifier_cv.py
@@ -0,0 +1,25 @@
+import numpy as np
+
+from sklearn.utils.testing import assert_equal
+from sklearn.linear_model.ridge import RidgeClassifierCV
+from sklearn import datasets
+
+
+def test_ridge_classifier_cv_store_cv_values():
+    """Test that RidgeClassifierCV supports store_cv_values=True."""
+    iris = datasets.load_iris()
+    X_iris = iris.data
+    y_iris = iris.target
+    n_samples = X_iris.shape[0]
+    n_classes = len(np.unique(y_iris))
+    alphas = [0.1, 1.0, 10.0]
+
+    # This call raises a TypeError in the buggy version.
+    # When fixed, it should accept the argument and assign cv_values_.
+    clf = RidgeClassifierCV(alphas=alphas, store_cv_values=True)
+    clf.fit(X_iris, y_iris)
+
+    # This assertion will pass when the bug is fixed.
+    # The shape is (n_samples, n_classes, n_alphas) because RidgeClassifierCV
+    # uses a one-vs-all scheme, where each class gets a RidgeCV model.
+    assert_equal(clf.cv_values_.shape, (n_samples, n_classes, len(alphas)))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/linear_model/ridge\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/linear_model/tests/test_ridge_classifier_cv.py
cat coverage.cover
git checkout b90661d6a46aa3619d3eec94d5281f5888add501
git apply /root/pre_state.patch
