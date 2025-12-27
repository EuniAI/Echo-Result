#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 179ee13eb37348cd87169a198aec18fedccc8668 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 179ee13eb37348cd87169a198aec18fedccc8668
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/staticfiles/tests/test_post_process.py b/django/contrib/staticfiles/tests/test_post_process.py
new file mode 100644
index 0000000000..35877fccef
--- /dev/null
+++ b/django/contrib/staticfiles/tests/test_post_process.py
@@ -0,0 +1,46 @@
+import os
+from collections import Counter
+
+from django.contrib.staticfiles.management.commands.collectstatic import (
+    Command as CollectstaticCommand,
+)
+from django.test import override_settings
+
+from .cases import CollectionTestCase
+
+
+@override_settings(
+    STATICFILES_STORAGE='django.contrib.staticfiles.storage.ManifestStaticFilesStorage'
+)
+class HashedFilesMixinPostProcessYieldsTests(CollectionTestCase):
+    run_collectstatic_in_setUp = False
+
+    def test_post_process_yields_once_per_file(self):
+        """
+        HashedFilesMixin.post_process() should not yield the same file more
+        than once.
+        """
+        self.run_collectstatic()
+
+        collectstatic_cmd = CollectstaticCommand()
+        # All options must be passed to set_options() to avoid a KeyError.
+        collectstatic_args = {
+            'interactive': False,
+            'verbosity': 0,
+            'link': False,
+            'clear': False,
+            'dry_run': False,
+            'post_process': True,
+            'use_default_ignore_patterns': True,
+            'ignore_patterns': ['*.ignoreme'],
+        }
+        collectstatic_cmd.set_options(**collectstatic_args)
+        stats = collectstatic_cmd.collect()
+        post_processed_files = stats['post_processed']
+
+        counts = Counter(os.path.normpath(p) for p in post_processed_files)
+        # A file that is adjustable (contains references to other static
+        # files) and is subject to multiple processing passes.
+        adjustable_file = os.path.normpath('cached/relative.css')
+        self.assertIn(adjustable_file, counts)
+        self.assertEqual(counts[adjustable_file], 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/staticfiles/storage\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 django.contrib.staticfiles.tests.test_post_process
cat coverage.cover
git checkout 179ee13eb37348cd87169a198aec18fedccc8668
git apply /root/pre_state.patch
