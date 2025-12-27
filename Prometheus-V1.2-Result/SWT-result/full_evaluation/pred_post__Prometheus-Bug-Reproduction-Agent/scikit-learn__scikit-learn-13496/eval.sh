#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3aefc834dce72e850bff48689bea3c7dff5f3fad >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3aefc834dce72e850bff48689bea3c7dff5f3fad
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/ensemble/iforest.py b/sklearn/ensemble/iforest.py
--- a/sklearn/ensemble/iforest.py
+++ b/sklearn/ensemble/iforest.py
@@ -120,6 +120,12 @@ class IsolationForest(BaseBagging, OutlierMixin):
     verbose : int, optional (default=0)
         Controls the verbosity of the tree building process.
 
+    warm_start : bool, optional (default=False)
+        When set to ``True``, reuse the solution of the previous call to fit
+        and add more estimators to the ensemble, otherwise, just fit a whole
+        new forest. See :term:`the Glossary <warm_start>`.
+
+        .. versionadded:: 0.21
 
     Attributes
     ----------
@@ -173,7 +179,8 @@ def __init__(self,
                  n_jobs=None,
                  behaviour='old',
                  random_state=None,
-                 verbose=0):
+                 verbose=0,
+                 warm_start=False):
         super().__init__(
             base_estimator=ExtraTreeRegressor(
                 max_features=1,
@@ -185,6 +192,7 @@ def __init__(self,
             n_estimators=n_estimators,
             max_samples=max_samples,
             max_features=max_features,
+            warm_start=warm_start,
             n_jobs=n_jobs,
             random_state=random_state,
             verbose=verbose)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/ensemble/tests/test_warm_start.py b/sklearn/ensemble/tests/test_warm_start.py
new file mode 100644
index 0000000000..cf79fd39f9
--- /dev/null
+++ b/sklearn/ensemble/tests/test_warm_start.py
@@ -0,0 +1,25 @@
+import pytest
+from sklearn.datasets import make_hastie_10_2
+from sklearn.ensemble import IsolationForest
+from sklearn.utils._testing import assert_array_equal
+
+
+def test_isolation_forest_warm_start():
+    """Test warm-start for IsolationForest.
+
+    A TypeError should be raised because warm_start is not in __init__.
+    When the parameter is exposed, this test should pass.
+    """
+    X, y = make_hastie_10_2(random_state=0)
+
+    clf_warm = IsolationForest(n_estimators=5, warm_start=True, random_state=42)
+    clf_warm.fit(X, y)
+
+    clf_warm.set_params(n_estimators=10)
+    clf_warm.fit(X, y)
+
+    clf_cold = IsolationForest(n_estimators=10, warm_start=False, random_state=42)
+    clf_cold.fit(X, y)
+
+    # The two forests should be identical.
+    assert_array_equal(clf_warm.apply(X), clf_cold.apply(X))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/ensemble/iforest\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/ensemble/tests/test_warm_start.py
cat coverage.cover
git checkout 3aefc834dce72e850bff48689bea3c7dff5f3fad
git apply /root/pre_state.patch
