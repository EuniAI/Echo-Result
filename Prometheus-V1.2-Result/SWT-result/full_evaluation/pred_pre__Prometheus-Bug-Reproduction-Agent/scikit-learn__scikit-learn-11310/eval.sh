#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 553b5fb8f84ba05c8397f26dd079deece2b05029 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 553b5fb8f84ba05c8397f26dd079deece2b05029
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/model_selection/tests/test_refit_time.py b/sklearn/model_selection/tests/test_refit_time.py
new file mode 100644
index 0000000000..5954828847
--- /dev/null
+++ b/sklearn/model_selection/tests/test_refit_time.py
@@ -0,0 +1,27 @@
+import pytest
+from sklearn.datasets import load_iris
+from sklearn.ensemble import RandomForestClassifier
+from sklearn.model_selection import GridSearchCV, RandomizedSearchCV
+
+
+def test_search_cv_refit_time():
+    """Test that refit_time_ is recorded for BaseSearchCV."""
+    X, y = load_iris(return_X_y=True)
+
+    search_configs = [
+        (GridSearchCV, {'param_grid': {'n_estimators': [2, 3]}}),
+        (RandomizedSearchCV, {'param_distributions': {'n_estimators': [2, 3]},
+                              'n_iter': 1})
+    ]
+
+    for SearchCV, params in search_configs:
+        search = SearchCV(
+            estimator=RandomForestClassifier(random_state=0),
+            **params,
+            cv=3
+        )
+        search.fit(X, y)
+
+        assert hasattr(search, 'refit_time_')
+        assert isinstance(search.refit_time_, float)
+        assert search.refit_time_ >= 0

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/model_selection/_search\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/model_selection/tests/test_refit_time.py
cat coverage.cover
git checkout 553b5fb8f84ba05c8397f26dd079deece2b05029
git apply /root/pre_state.patch
