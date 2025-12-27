#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 06632c0d185128a53c57ccc73b25b6408e90bb89 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 06632c0d185128a53c57ccc73b25b6408e90bb89
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/model_selection/_split.py b/sklearn/model_selection/_split.py
--- a/sklearn/model_selection/_split.py
+++ b/sklearn/model_selection/_split.py
@@ -1163,6 +1163,9 @@ def get_n_splits(self, X=None, y=None, groups=None):
                      **self.cvargs)
         return cv.get_n_splits(X, y, groups) * self.n_repeats
 
+    def __repr__(self):
+        return _build_repr(self)
+
 
 class RepeatedKFold(_RepeatedSplits):
     """Repeated K-Fold cross validator.
@@ -2158,6 +2161,8 @@ def _build_repr(self):
         try:
             with warnings.catch_warnings(record=True) as w:
                 value = getattr(self, key, None)
+                if value is None and hasattr(self, 'cvargs'):
+                    value = self.cvargs.get(key, None)
             if len(w) and w[0].category == DeprecationWarning:
                 # if the parameter is deprecated, don't show it
                 continue

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/model_selection/tests/test_repeated_cross_validator.py b/sklearn/model_selection/tests/test_repeated_cross_validator.py
new file mode 100644
index 0000000000..f29be72920
--- /dev/null
+++ b/sklearn/model_selection/tests/test_repeated_cross_validator.py
@@ -0,0 +1,17 @@
+import numpy as np
+
+from sklearn.model_selection import RepeatedKFold
+from sklearn.model_selection import RepeatedStratifiedKFold
+
+
+def test_repeated_cross_validator_repr():
+    """Check the __repr__ methods of RepeatedKFold and RepeatedStratifiedKFold."""
+    # Test for RepeatedKFold
+    rkf = RepeatedKFold()
+    expected_rkf_repr = "RepeatedKFold(n_splits=5, n_repeats=10, random_state=None)"
+    assert repr(rkf) == expected_rkf_repr
+
+    # Test for RepeatedStratifiedKFold
+    rskf = RepeatedStratifiedKFold()
+    expected_rskf_repr = "RepeatedStratifiedKFold(n_splits=5, n_repeats=10, random_state=None)"
+    assert repr(rskf) == expected_rskf_repr

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/model_selection/_split\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/model_selection/tests/test_repeated_cross_validator.py
cat coverage.cover
git checkout 06632c0d185128a53c57ccc73b25b6408e90bb89
git apply /root/pre_state.patch
