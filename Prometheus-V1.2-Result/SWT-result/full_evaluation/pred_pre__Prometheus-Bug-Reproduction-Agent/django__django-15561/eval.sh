#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6991880109e35c879b71b7d9d9c154baeec12b89 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6991880109e35c879b71b7d9d9c154baeec12b89
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_alter_field.py b/tests/migrations/test_alter_field.py
new file mode 100644
index 0000000000..a28e10070b
--- /dev/null
+++ b/tests/migrations/test_alter_field.py
@@ -0,0 +1,38 @@
+import unittest
+
+from django.db import connection, migrations, models
+from django.test import skipUnlessDBFeature
+
+from .test_base import OperationTestBase
+
+
+class MigrationTests(OperationTestBase):
+    @skipUnlessDBFeature("can_introspect_foreign_keys")
+    def test_alter_field_choices_is_noop(self):
+        """
+        AlterField should be a no-op when adding or changing choices as this
+        is not a database-level change. On SQLite, this was not the case
+        (#33475).
+        """
+        app_label = "test_afcinoop"
+        project_state = self.set_up_test_model(app_label)
+        operation = migrations.AlterField(
+            "Pony",
+            "pink",
+            models.IntegerField(default=3, choices=[(1, "A"), (2, "B")]),
+        )
+        new_state = project_state.clone()
+        operation.state_forwards(app_label, new_state)
+
+        self.assertIsNone(project_state.models[app_label, "pony"].fields["pink"].choices)
+        self.assertIsNotNone(new_state.models[app_label, "pony"].fields["pink"].choices)
+        # This should be a no-op on the database.
+        with connection.schema_editor() as editor:
+            with self.assertNumQueries(0):
+                operation.database_forwards(app_label, editor, project_state, new_state)
+        # And backwards.
+        with connection.schema_editor() as editor:
+            with self.assertNumQueries(0):
+                operation.database_backwards(
+                    app_label, editor, new_state, project_state
+                )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/base/schema\.py|django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_alter_field
cat coverage.cover
git checkout 6991880109e35c879b71b7d9d9c154baeec12b89
git apply /root/pre_state.patch
