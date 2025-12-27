#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9f0b959a8c9195d1b6e203f08b698e052b426ca9 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9f0b959a8c9195d1b6e203f08b698e052b426ca9
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/model_selection/tests/test_stratified_kfold_bug_13114.py b/sklearn/model_selection/tests/test_stratified_kfold_bug_13114.py
new file mode 100644
index 0000000000..e01df66036
--- /dev/null
+++ b/sklearn/model_selection/tests/test_stratified_kfold_bug_13114.py
@@ -0,0 +1,33 @@
+import numpy as np
+from sklearn.model_selection import StratifiedKFold
+from sklearn.utils.testing import assert_not_equal
+
+
+def test_stratified_kfold_shuffle_bug_13114():
+    # Test for bug #13114
+    # StratifiedKFold with shuffle=True should shuffle samples inside each
+    # stratum. The bug is that it shuffles the order of the folds,
+    # and not the samples in each stratum.
+    samples_per_class = 10
+    X = np.zeros(samples_per_class * 2)
+    y = np.concatenate((np.ones(samples_per_class),
+                        np.zeros(samples_per_class)), axis=0)
+    n_splits = 10
+
+    # With shuffle=True, different random_state should lead to different
+    # splits, not just a different ordering of the same splits.
+    skf_1 = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=1)
+    splits_1 = [test for _, test in skf_1.split(X, y)]
+
+    skf_2 = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=2)
+    splits_2 = [test for _, test in skf_2.split(X, y)]
+
+    # The bug is that the set of folds is identical, only the order changes.
+    # After the fix, the sets of folds should be different.
+    # We sort the indices within each fold and then convert to a tuple to make
+    # them hashable for the set.
+    set_of_folds_1 = {tuple(np.sort(s)) for s in splits_1}
+    set_of_folds_2 = {tuple(np.sort(s)) for s in splits_2}
+
+    # This assertion will fail if the bug is present, and pass when fixed.
+    assert_not_equal(set_of_folds_1, set_of_folds_2)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/model_selection/_split\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/model_selection/tests/test_stratified_kfold_bug_13114.py
cat coverage.cover
git checkout 9f0b959a8c9195d1b6e203f08b698e052b426ca9
git apply /root/pre_state.patch
