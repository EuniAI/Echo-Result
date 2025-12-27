#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 8c3bd0b708b488a1f6e8bd8cc6b96569904605be >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 8c3bd0b708b488a1f6e8bd8cc6b96569904605be
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_executor_squashed.py b/tests/migrations/test_executor_squashed.py
new file mode 100644
index 0000000000..ffff878f7b
--- /dev/null
+++ b/tests/migrations/test_executor_squashed.py
@@ -0,0 +1,31 @@
+from django.db import connection
+from django.db.migrations.executor import MigrationExecutor
+from django.db.migrations.recorder import MigrationRecorder
+from django.test import override_settings
+
+from .test_base import MigrationTestBase
+
+
+class ExecutorSquashedTests(MigrationTestBase):
+    available_apps = [
+        "migrations",
+        "django.contrib.auth",
+        "django.contrib.contenttypes",
+    ]
+
+    @override_settings(MIGRATION_MODULES={"migrations": "migrations.test_migrations_squashed"})
+    def test_unapply_squashed_migration_removes_record(self):
+        """
+        When a squashed migration is unapplied and the replaced migration
+        files are present, the squashed migration is marked as unapplied.
+        """
+        executor = MigrationExecutor(connection)
+        # Apply the squashed migration.
+        executor.migrate([("migrations", "0001_squashed_0002")])
+        # Unapply all migrations.
+        executor.loader.build_graph()
+        executor.migrate([("migrations", None)])
+        # After unapplying, the squashed migration should be marked as unapplied.
+        recorder = MigrationRecorder(connection)
+        applied_migrations = recorder.applied_migrations()
+        self.assertNotIn(("migrations", "0001_squashed_0002"), applied_migrations)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/executor\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_executor_squashed
cat coverage.cover
git checkout 8c3bd0b708b488a1f6e8bd8cc6b96569904605be
git apply /root/pre_state.patch
