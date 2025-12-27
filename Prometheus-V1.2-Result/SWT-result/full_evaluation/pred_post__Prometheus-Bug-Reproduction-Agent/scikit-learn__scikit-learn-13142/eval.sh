#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1c8668b0a021832386470ddf740d834e02c66f69 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1c8668b0a021832386470ddf740d834e02c66f69
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/mixture/base.py b/sklearn/mixture/base.py
--- a/sklearn/mixture/base.py
+++ b/sklearn/mixture/base.py
@@ -257,11 +257,6 @@ def fit_predict(self, X, y=None):
                 best_params = self._get_parameters()
                 best_n_iter = n_iter
 
-        # Always do a final e-step to guarantee that the labels returned by
-        # fit_predict(X) are always consistent with fit(X).predict(X)
-        # for any value of max_iter and tol (and any random_state).
-        _, log_resp = self._e_step(X)
-
         if not self.converged_:
             warnings.warn('Initialization %d did not converge. '
                           'Try different init parameters, '
@@ -273,6 +268,11 @@ def fit_predict(self, X, y=None):
         self.n_iter_ = best_n_iter
         self.lower_bound_ = max_lower_bound
 
+        # Always do a final e-step to guarantee that the labels returned by
+        # fit_predict(X) are always consistent with fit(X).predict(X)
+        # for any value of max_iter and tol (and any random_state).
+        _, log_resp = self._e_step(X)
+
         return log_resp.argmax(axis=1)
 
     def _e_step(self, X):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/mixture/tests/test_gaussian_mixture_issue_13201.py b/sklearn/mixture/tests/test_gaussian_mixture_issue_13201.py
new file mode 100644
index 0000000000..eed9f3c8c6
--- /dev/null
+++ b/sklearn/mixture/tests/test_gaussian_mixture_issue_13201.py
@@ -0,0 +1,48 @@
+import sys
+import copy
+import warnings
+import pytest
+
+import numpy as np
+from scipy import stats, linalg
+
+from sklearn.covariance import EmpiricalCovariance
+from sklearn.datasets.samples_generator import make_spd_matrix
+from io import StringIO
+from sklearn.metrics.cluster import adjusted_rand_score
+from sklearn.mixture.gaussian_mixture import GaussianMixture
+from sklearn.mixture.gaussian_mixture import (
+    _estimate_gaussian_covariances_full,
+    _estimate_gaussian_covariances_tied,
+    _estimate_gaussian_covariances_diag,
+    _estimate_gaussian_covariances_spherical)
+from sklearn.mixture.gaussian_mixture import _compute_precision_cholesky
+from sklearn.mixture.gaussian_mixture import _compute_log_det_cholesky
+from sklearn.exceptions import ConvergenceWarning, NotFittedError
+from sklearn.utils.extmath import fast_logdet
+from sklearn.utils.testing import assert_allclose
+from sklearn.utils.testing import assert_almost_equal
+from sklearn.utils.testing import assert_array_almost_equal
+from sklearn.utils.testing import assert_array_equal
+from sklearn.utils.testing import assert_equal
+from sklearn.utils.testing import assert_greater
+from sklearn.utils.testing import assert_greater_equal
+from sklearn.utils.testing import assert_raise_message
+from sklearn.utils.testing import assert_warns_message
+from sklearn.utils.testing import ignore_warnings
+
+
+def test_gaussian_mixture_fit_predict_n_init():
+    # Non-regression test for issue #13201.
+    # Checks that fit_predict and predict give same results when n_init > 1.
+    rng = np.random.RandomState(0)
+    X = rng.randn(1000, 5)
+
+    gm = GaussianMixture(n_components=5, n_init=5, random_state=rng)
+
+    # The result of fit_predict should be the same as predict on the same
+    # fitted model.
+    y_fit_predict = gm.fit_predict(X)
+    y_predict = gm.predict(X)
+
+    assert_array_equal(y_fit_predict, y_predict)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/mixture/base\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/mixture/tests/test_gaussian_mixture_issue_13201.py
cat coverage.cover
git checkout 1c8668b0a021832386470ddf740d834e02c66f69
git apply /root/pre_state.patch
