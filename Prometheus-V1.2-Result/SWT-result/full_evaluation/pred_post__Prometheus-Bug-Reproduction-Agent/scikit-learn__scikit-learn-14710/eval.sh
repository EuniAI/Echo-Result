#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 4b6273b87442a4437d8b3873ea3022ae163f4fdf >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 4b6273b87442a4437d8b3873ea3022ae163f4fdf
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/ensemble/_hist_gradient_boosting/gradient_boosting.py b/sklearn/ensemble/_hist_gradient_boosting/gradient_boosting.py
--- a/sklearn/ensemble/_hist_gradient_boosting/gradient_boosting.py
+++ b/sklearn/ensemble/_hist_gradient_boosting/gradient_boosting.py
@@ -426,11 +426,15 @@ def _check_early_stopping_scorer(self, X_binned_small_train, y_small_train,
 
         Scores are computed on validation data or on training data.
         """
+        if is_classifier(self):
+            y_small_train = self.classes_[y_small_train.astype(int)]
         self.train_score_.append(
             self.scorer_(self, X_binned_small_train, y_small_train)
         )
 
         if self._use_validation_data:
+            if is_classifier(self):
+                y_val = self.classes_[y_val.astype(int)]
             self.validation_score_.append(
                 self.scorer_(self, X_binned_val, y_val)
             )

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/ensemble/_hist_gradient_boosting/tests/test_hist_gradient_boosting_regressions.py b/sklearn/ensemble/_hist_gradient_boosting/tests/test_hist_gradient_boosting_regressions.py
new file mode 100644
index 0000000000..a96f299c98
--- /dev/null
+++ b/sklearn/ensemble/_hist_gradient_boosting/tests/test_hist_gradient_boosting_regressions.py
@@ -0,0 +1,20 @@
+import numpy as np
+import pytest
+
+# To use this experimental feature, we need to explicitly ask for it:
+from sklearn.experimental import enable_hist_gradient_boosting  # noqa
+from sklearn.ensemble import HistGradientBoostingClassifier
+
+
+def test_early_stopping_with_string_target():
+    """Check that early stopping works with string classes.
+
+    Non-regression test for #14981.
+    """
+    X = np.random.randn(100, 10)
+    y = np.array(['x'] * 50 + ['y'] * 50, dtype=object)
+    gbrt = HistGradientBoostingClassifier(n_iter_no_change=10)
+
+    # This should not raise:
+    # TypeError: '<' not supported between instances of 'str' and 'float'
+    gbrt.fit(X, y)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/ensemble/_hist_gradient_boosting/gradient_boosting\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/ensemble/_hist_gradient_boosting/tests/test_hist_gradient_boosting_regressions.py
cat coverage.cover
git checkout 4b6273b87442a4437d8b3873ea3022ae163f4fdf
git apply /root/pre_state.patch
