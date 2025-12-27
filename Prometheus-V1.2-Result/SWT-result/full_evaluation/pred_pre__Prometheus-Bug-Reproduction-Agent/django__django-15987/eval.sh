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
diff --git a/tests/fixtures_regress/test_fixture_pathlib.py b/tests/fixtures_regress/test_fixture_pathlib.py
new file mode 100644
index 0000000000..7bb4cfb4d1
--- /dev/null
+++ b/tests/fixtures_regress/test_fixture_pathlib.py
@@ -0,0 +1,26 @@
+import os
+from pathlib import Path
+
+from django.core import management
+from django.core.exceptions import ImproperlyConfigured
+from django.test import TransactionTestCase, override_settings
+
+_cur_dir = os.path.dirname(os.path.abspath(__file__))
+
+
+class FixturesTestCase(TransactionTestCase):
+    available_apps = ["fixtures_regress"]
+
+    @override_settings(FIXTURE_DIRS=[Path(_cur_dir) / "fixtures"])
+    def test_fixture_dirs_with_default_fixture_path_pathlib(self):
+        """
+        settings.FIXTURE_DIRS cannot contain a default fixtures directory for an
+        application, even if it is a pathlib.Path instance.
+        """
+        msg = (
+            "'%s' is a default fixture directory for the '%s' app "
+            "and cannot be listed in settings.FIXTURE_DIRS."
+            % (Path(_cur_dir) / "fixtures", "fixtures_regress")
+        )
+        with self.assertRaisesMessage(ImproperlyConfigured, msg):
+            management.call_command("loaddata", "absolute.json", verbosity=0)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/loaddata\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 fixtures_regress.test_fixture_pathlib
cat coverage.cover
git checkout 7e6b537f5b92be152779fc492bb908d27fe7c52a
git apply /root/pre_state.patch
