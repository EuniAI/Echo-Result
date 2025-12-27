#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e3d1f9ac39e4bf0f31430e779acc50fb05fe1b64 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e3d1f9ac39e4bf0f31430e779acc50fb05fe1b64
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/ensemble/tests/test_iforest_issue_25824.py b/sklearn/ensemble/tests/test_iforest_issue_25824.py
new file mode 100644
index 0000000000..ca0b3c17d9
--- /dev/null
+++ b/sklearn/ensemble/tests/test_iforest_issue_25824.py
@@ -0,0 +1,24 @@
+import warnings
+import pandas as pd
+import pytest
+
+from sklearn.ensemble import IsolationForest
+
+
+def test_iforest_fit_dataframe_with_contamination_no_warning():
+    """Check that fitting with a dataframe and contamination does not raise a
+    warning about feature names.
+
+    Non-regression test for #25824.
+    """
+    X = pd.DataFrame({"a": [-1.1, 0.3, 0.5, 100]})
+    clf = IsolationForest(random_state=0, contamination=0.05)
+
+    # This should not raise "X does not have valid feature names..."
+    with warnings.catch_warnings():
+        warnings.filterwarnings(
+            "error",
+            message="X does not have valid feature names",
+            category=UserWarning,
+        )
+        clf.fit(X)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/ensemble/_iforest\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/ensemble/tests/test_iforest_issue_25824.py
cat coverage.cover
git checkout e3d1f9ac39e4bf0f31430e779acc50fb05fe1b64
git apply /root/pre_state.patch
