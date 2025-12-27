#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7272e1963ffdf39c1d4fe225d5425a45dd095d11 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7272e1963ffdf39c1d4fe225d5425a45dd095d11
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/staticfiles/storage.py b/django/contrib/staticfiles/storage.py
--- a/django/contrib/staticfiles/storage.py
+++ b/django/contrib/staticfiles/storage.py
@@ -260,6 +260,7 @@ def post_process(self, paths, dry_run=False, **options):
                 processed_adjustable_paths[name] = (name, hashed_name, processed)
 
         paths = {path: paths[path] for path in adjustable_paths}
+        substitutions = False
 
         for i in range(self.max_post_process_passes):
             substitutions = False

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/staticfiles_tests/test_post_processing_passes.py b/staticfiles_tests/test_post_processing_passes.py
new file mode 100644
index 0000000000..59e8a2de79
--- /dev/null
+++ b/staticfiles_tests/test_post_processing_passes.py
@@ -0,0 +1,23 @@
+from django.contrib.staticfiles.storage import ManifestStaticFilesStorage
+from django.test import override_settings
+
+from .cases import CollectionTestCase
+
+
+class MaxPostProcessPassesZeroStorage(ManifestStaticFilesStorage):
+    max_post_process_passes = 0
+
+
+@override_settings(
+    STATICFILES_STORAGE='staticfiles_tests.test_storage.MaxPostProcessPassesZeroStorage',
+)
+class PostprocessingPassesTest(CollectionTestCase):
+    run_collectstatic_in_setUp = False
+
+    def test_max_post_process_passes_zero(self):
+        """
+        collectstatic should not crash when max_post_process_passes is set to 0.
+        """
+        # This call raises UnboundLocalError before the fix. After the fix, it
+        # will complete successfully.
+        self.run_collectstatic()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/staticfiles/storage\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 staticfiles_tests.test_post_processing_passes
cat coverage.cover
git checkout 7272e1963ffdf39c1d4fe225d5425a45dd095d11
git apply /root/pre_state.patch
