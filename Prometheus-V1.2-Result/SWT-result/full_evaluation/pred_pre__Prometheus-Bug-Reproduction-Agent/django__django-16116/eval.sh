#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5d36a8266c7d5d1994d7a7eeb4016f80d9cb0401 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5d36a8266c7d5d1994d7a7eeb4016f80d9cb0401
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_makemigrations.py b/tests/migrations/test_makemigrations.py
new file mode 100644
index 0000000000..072a573567
--- /dev/null
+++ b/tests/migrations/test_makemigrations.py
@@ -0,0 +1,43 @@
+import io
+import os
+
+from django.apps import apps
+from django.core.management import call_command
+from django.db import models
+from django.test import SimpleTestCase, override_settings
+
+from .test_base import MigrationTestBase
+
+
+class MakeMigrationsTests(MigrationTestBase):
+    """
+    Tests running the makemigrations command.
+    """
+
+    def setUp(self):
+        super().setUp()
+        self._old_models = apps.app_configs["migrations"].models.copy()
+
+    def tearDown(self):
+        apps.app_configs["migrations"].models = self._old_models
+        apps.all_models["migrations"] = self._old_models
+
+    def test_makemigrations_check_exits_without_creating_files(self):
+        """
+        makemigrations --check should exit with a non-zero status code without
+        creating migration files.
+        """
+        # A new model is needed so that makemigrations detects changes.
+        class Author(models.Model):
+            name = models.CharField(max_length=255)
+
+            class Meta:
+                app_label = "migrations"
+
+        # The --check flag should exit with a non-zero status code if
+        # migrations are pending.
+        with self.temporary_migration_module() as migration_dir:
+            with self.assertRaises(SystemExit):
+                call_command("makemigrations", "--check", "migrations")
+            # And it should not create any files.
+            self.assertEqual(os.listdir(migration_dir), [])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/makemigrations\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_makemigrations
cat coverage.cover
git checkout 5d36a8266c7d5d1994d7a7eeb4016f80d9cb0401
git apply /root/pre_state.patch
