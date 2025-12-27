#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6ab8c86c383dd847a1be7103ad115f174fe23ffd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6ab8c86c383dd847a1be7103ad115f174fe23ffd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/tree/tests/test_export_text.py b/sklearn/tree/tests/test_export_text.py
new file mode 100644
index 0000000000..a7028e38b0
--- /dev/null
+++ b/sklearn/tree/tests/test_export_text.py
@@ -0,0 +1,20 @@
+from sklearn.tree import DecisionTreeClassifier
+from sklearn.tree.export import export_text
+from sklearn.datasets import load_iris
+
+
+def test_export_text_single_feature():
+    """Test export_text with a single feature.
+
+    Non-regression test for #14444. It checks that export_text does not raise
+    an IndexError when the tree is trained on a single feature.
+    """
+    X, y = load_iris(return_X_y=True)
+    X = X[:, 0].reshape(-1, 1)
+
+    tree = DecisionTreeClassifier(random_state=0)
+    tree.fit(X, y)
+    tree_text = export_text(tree, feature_names=['sepal_length'])
+
+    assert isinstance(tree_text, str)
+    assert 'sepal_length' in tree_text

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/tree/export\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/tree/tests/test_export_text.py
cat coverage.cover
git checkout 6ab8c86c383dd847a1be7103ad115f174fe23ffd
git apply /root/pre_state.patch
