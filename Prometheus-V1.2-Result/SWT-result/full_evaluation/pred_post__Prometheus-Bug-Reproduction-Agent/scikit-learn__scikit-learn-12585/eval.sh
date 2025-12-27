#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD bfc4a566423e036fbdc9fb02765fd893e4860c85 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff bfc4a566423e036fbdc9fb02765fd893e4860c85
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/base.py b/sklearn/base.py
--- a/sklearn/base.py
+++ b/sklearn/base.py
@@ -48,7 +48,7 @@ def clone(estimator, safe=True):
     # XXX: not handling dictionaries
     if estimator_type in (list, tuple, set, frozenset):
         return estimator_type([clone(e, safe=safe) for e in estimator])
-    elif not hasattr(estimator, 'get_params'):
+    elif not hasattr(estimator, 'get_params') or isinstance(estimator, type):
         if not safe:
             return copy.deepcopy(estimator)
         else:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/tests/test_clone.py b/sklearn/tests/test_clone.py
new file mode 100644
index 0000000000..a56eab19c1
--- /dev/null
+++ b/sklearn/tests/test_clone.py
@@ -0,0 +1,36 @@
+import numpy as np
+import scipy.sparse as sp
+
+import sklearn
+from sklearn.utils.testing import assert_array_equal
+from sklearn.utils.testing import assert_true
+from sklearn.utils.testing import assert_false
+from sklearn.utils.testing import assert_equal
+from sklearn.utils.testing import assert_not_equal
+from sklearn.utils.testing import assert_raises
+from sklearn.utils.testing import assert_no_warnings
+from sklearn.utils.testing import assert_warns_message
+from sklearn.utils.testing import assert_dict_equal
+from sklearn.utils.testing import ignore_warnings
+
+from sklearn.base import BaseEstimator, clone, is_classifier
+from sklearn.svm import SVC
+from sklearn.pipeline import Pipeline
+from sklearn.model_selection import GridSearchCV
+from sklearn.preprocessing import StandardScaler
+
+from sklearn.tree import DecisionTreeClassifier
+from sklearn.tree import DecisionTreeRegressor
+from sklearn import datasets
+
+from sklearn.base import TransformerMixin
+from sklearn.utils.mocking import MockDataFrame
+import pickle
+
+
+def test_clone_estimator_types_as_parameter():
+    """Test that clone works for parameters that are estimator types."""
+    # This was a bug in 0.20.0, see #12482
+    estimator = StandardScaler(with_mean=StandardScaler)
+    cloned_estimator = clone(estimator)
+    assert cloned_estimator.with_mean is StandardScaler

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/base\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/tests/test_clone.py
cat coverage.cover
git checkout bfc4a566423e036fbdc9fb02765fd893e4860c85
git apply /root/pre_state.patch
