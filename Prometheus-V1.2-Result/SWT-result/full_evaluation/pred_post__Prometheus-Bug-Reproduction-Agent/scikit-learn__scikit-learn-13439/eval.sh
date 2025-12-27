#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a62775e99f2a5ea3d51db7160fad783f6cd8a4c5 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a62775e99f2a5ea3d51db7160fad783f6cd8a4c5
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -v --no-use-pep517 --no-build-isolation -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/pipeline.py b/sklearn/pipeline.py
--- a/sklearn/pipeline.py
+++ b/sklearn/pipeline.py
@@ -199,6 +199,12 @@ def _iter(self, with_final=True):
             if trans is not None and trans != 'passthrough':
                 yield idx, name, trans
 
+    def __len__(self):
+        """
+        Returns the length of the Pipeline
+        """
+        return len(self.steps)
+
     def __getitem__(self, ind):
         """Returns a sub-pipeline or a single esimtator in the pipeline
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sklearn/tests/test_pipeline_len.py b/sklearn/tests/test_pipeline_len.py
new file mode 100644
index 0000000000..8b35ad60f9
--- /dev/null
+++ b/sklearn/tests/test_pipeline_len.py
@@ -0,0 +1,11 @@
+from sklearn.svm import SVC
+from sklearn.feature_selection import SelectKBest, f_regression
+from sklearn.pipeline import Pipeline
+
+
+def test_pipeline_len():
+    """Test that pipeline implements __len__."""
+    anova_filter = SelectKBest(f_regression, k=5)
+    clf = SVC(kernel='linear')
+    pipe = Pipeline([('anova', anova_filter), ('svc', clf)])
+    assert len(pipe) == 2

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sklearn/pipeline\.py)' -m pytest --no-header -rA  -p no:cacheprovider sklearn/tests/test_pipeline_len.py
cat coverage.cover
git checkout a62775e99f2a5ea3d51db7160fad783f6cd8a4c5
git apply /root/pre_state.patch
