#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fdbaa58acbead5a254f2e6d597dc1ab3b947f4c6 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fdbaa58acbead5a254f2e6d597dc1ab3b947f4c6
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/svm/base.py b/sklearn/svm/base.py
--- a/sklearn/svm/base.py
+++ b/sklearn/svm/base.py
@@ -287,11 +287,14 @@ def _sparse_fit(self, X, y, sample_weight, solver_type, kernel,
         n_SV = self.support_vectors_.shape[0]
 
         dual_coef_indices = np.tile(np.arange(n_SV), n_class)
-        dual_coef_indptr = np.arange(0, dual_coef_indices.size + 1,
-                                     dual_coef_indices.size / n_class)
-        self.dual_coef_ = sp.csr_matrix(
-            (dual_coef_data, dual_coef_indices, dual_coef_indptr),
-            (n_class, n_SV))
+        if not n_SV:
+            self.dual_coef_ = sp.csr_matrix([])
+        else:
+            dual_coef_indptr = np.arange(0, dual_coef_indices.size + 1,
+                                         dual_coef_indices.size / n_class)
+            self.dual_coef_ = sp.csr_matrix(
+                (dual_coef_data, dual_coef_indices, dual_coef_indptr),
+                (n_class, n_SV))
 
     def predict(self, X):
         """Perform regression on samples in X.

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/svm/tests/test_svr_sparse_empty_support_vectors.py b/sklearn/svm/tests/test_svr_sparse_empty_support_vectors.py
new file mode 100644
index 0000000000..7117e26cfa
--- /dev/null
+++ b/sklearn/svm/tests/test_svr_sparse_empty_support_vectors.py
@@ -0,0 +1,31 @@
+import numpy as np
+import pytest
+from scipy import sparse
+from sklearn.svm import SVR
+
+
+def test_svr_sparse_empty_support_vectors():
+    """Test for ZeroDivisionError in SVR._sparse_fit.
+
+    When fitting on sparse data and the resulting `support_vectors_`
+    is empty, a ZeroDivisionError was raised.
+
+    Regression test for scikit-learn/scikit-learn#14892.
+    """
+    x_train = np.array([[0, 1, 0, 0],
+                        [0, 0, 0, 1],
+                        [0, 0, 1, 0],
+                        [0, 0, 0, 1]])
+    y_train = np.array([0.04, 0.04, 0.10, 0.16])
+    model = SVR(C=316.227766017, cache_size=200, coef0=0.0, degree=3,
+                epsilon=0.1, gamma=1.0, kernel='linear', max_iter=15000,
+                shrinking=True, tol=0.001, verbose=False)
+
+    # convert to sparse
+    xtrain_sparse = sparse.csr_matrix(x_train)
+
+    # This should not raise a ZeroDivisionError
+    model.fit(xtrain_sparse, y_train)
+
+    # The model should fit without error and result in zero support vectors.
+    assert len(model.support_) == 0

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/svm/base\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/svm/tests/test_svr_sparse_empty_support_vectors.py
cat coverage.cover
git checkout fdbaa58acbead5a254f2e6d597dc1ab3b947f4c6
git apply /root/pre_state.patch
