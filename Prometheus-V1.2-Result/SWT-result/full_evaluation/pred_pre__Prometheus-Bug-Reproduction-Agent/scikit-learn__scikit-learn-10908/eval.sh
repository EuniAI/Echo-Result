#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 67d06b18c68ee4452768f8a1e868565dd4354abf >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 67d06b18c68ee4452768f8a1e868565dd4354abf
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/feature_extraction/tests/test_text_issue_6488.py b/sklearn/feature_extraction/tests/test_text_issue_6488.py
new file mode 100644
index 0000000000..ddd24aa84e
--- /dev/null
+++ b/sklearn/feature_extraction/tests/test_text_issue_6488.py
@@ -0,0 +1,21 @@
+from sklearn.feature_extraction.text import CountVectorizer
+from sklearn.utils.testing import assert_equal
+
+
+def test_get_feature_names_with_vocabulary_before_fit():
+    """Test get_feature_names with vocabulary before fitting the vectorizer.
+
+    Checks that CountVectorizer.get_feature_names does not raise a
+    NotFittedError if the vectorizer has not been fit, but was
+    instantiated with a vocabulary.
+
+    This is a non-regression test for:
+    https://github.com/scikit-learn/scikit-learn/issues/6488
+    """
+    vocab = ['and', 'document', 'first', 'is', 'one',
+             'second', 'the', 'third', 'this']
+    vectorizer = CountVectorizer(vocabulary=vocab)
+
+    # Currently this raises a NotFittedError.
+    feature_names = vectorizer.get_feature_names()
+    assert_equal(feature_names, vocab)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/feature_extraction/text\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/feature_extraction/tests/test_text_issue_6488.py
cat coverage.cover
git checkout 67d06b18c68ee4452768f8a1e868565dd4354abf
git apply /root/pre_state.patch
