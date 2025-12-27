#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7e6b537f5b92be152779fc492bb908d27fe7c52a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7e6b537f5b92be152779fc492bb908d27fe7c52a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_duplicate_fixture_dirs.py b/tests/test_duplicate_fixture_dirs.py
new file mode 100644
index 0000000000..84c3e33fc8
--- /dev/null
+++ b/tests/test_duplicate_fixture_dirs.py
@@ -0,0 +1,29 @@
+import os
+from pathlib import Path
+
+from django.core import management
+from django.core.exceptions import ImproperlyConfigured
+from django.test import TestCase, override_settings
+
+from fixtures_regress.models import Absolute
+
+_cur_dir = os.path.dirname(os.path.abspath(__file__))
+# Assume the test file is in `tests/` and the fixtures are in `tests/fixtures_regress/`
+_fixture_dir_path = os.path.join(_cur_dir, "fixtures_regress", "fixtures_1")
+
+
+class DuplicateFixtureDirsPathTest(TestCase):
+    @override_settings(
+        FIXTURE_DIRS=[
+            _fixture_dir_path,
+            Path(_fixture_dir_path),
+        ]
+    )
+    def test_fixture_dirs_duplicates_with_path_instance(self):
+        """
+        The duplicate check for settings.FIXTURE_DIRS should work correctly
+        even when the paths are a mix of strings and pathlib.Path instances.
+        """
+        msg = "settings.FIXTURE_DIRS contains duplicates."
+        with self.assertRaisesMessage(ImproperlyConfigured, msg):
+            management.call_command("loaddata", "absolute.json", verbosity=0)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/loaddata\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_duplicate_fixture_dirs
cat coverage.cover
git checkout 7e6b537f5b92be152779fc492bb908d27fe7c52a
git apply /root/pre_state.patch
