#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 361bb8f786f112ee275be136795c0b1ecefff928 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 361bb8f786f112ee275be136795c0b1ecefff928
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_migration_recorder_router.py b/tests/migrations/test_migration_recorder_router.py
new file mode 100644
index 0000000000..bc75649d0d
--- /dev/null
+++ b/tests/migrations/test_migration_recorder_router.py
@@ -0,0 +1,40 @@
+from unittest import mock
+
+from django.db import connections, router
+from django.db.migrations.recorder import MigrationRecorder
+from django.test import override_settings
+
+from .test_base import OperationTestBase
+
+
+class DenyOtherDBRouter:
+    """
+    A router that prevents any migrations on the 'other' database.
+    """
+    def allow_migrate(self, db, app_label, **hints):
+        return db == 'default'
+
+
+@override_settings(DATABASE_ROUTERS=['migrations.test_migration_recorder_router.DenyOtherDBRouter'])
+class MigrationRecorderRouterTests(OperationTestBase):
+    databases = {'default', 'other'}
+
+    @mock.patch.object(router, 'allow_migrate_model')
+    def test_recorder_methods_check_router(self, mock_allow_migrate_model):
+        """
+        MigrationRecorder methods should check the router to see if migrations
+        are allowed on a given database.
+        """
+        mock_allow_migrate_model.return_value = False
+        recorder = MigrationRecorder(connections['other'])
+
+        # These methods should all check the router before proceeding.
+        recorder.ensure_schema()
+        recorder.applied_migrations()
+        recorder.record_applied('app', '0001_initial')
+        recorder.record_unapplied('app', '0001_initial')
+
+        # The bug is that router.allow_migrate_model is not called.
+        # This assertion will fail with call_count == 0 before the fix.
+        # With the fix, the count will be 4.
+        self.assertEqual(mock_allow_migrate_model.call_count, 4)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/executor\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_migration_recorder_router
cat coverage.cover
git checkout 361bb8f786f112ee275be136795c0b1ecefff928
git apply /root/pre_state.patch
