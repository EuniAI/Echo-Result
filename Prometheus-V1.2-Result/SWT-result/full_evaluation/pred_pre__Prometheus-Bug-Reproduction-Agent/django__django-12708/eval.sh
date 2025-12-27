#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 447980e72ac01da1594dd3373a03ba40b7ee6f80 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 447980e72ac01da1594dd3373a03ba40b7ee6f80
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_alter_index_together.py b/tests/migrations/test_alter_index_together.py
new file mode 100644
index 0000000000..ff329c2f5c
--- /dev/null
+++ b/tests/migrations/test_alter_index_together.py
@@ -0,0 +1,82 @@
+from __future__ import unicode_literals
+
+from django.db import connection, migrations, models
+from django.db.migrations.state import ProjectState
+from django.test import TestCase, override_settings
+
+
+@override_settings(MIGRATION_MODULES={'test_remove_index_together_bug': None})
+class MigrationOperationsBugsTest(TestCase):
+    """
+    Tests for a bug where migration crashes deleting an index_together if
+    there is a unique_together on the same fields.
+    """
+
+    def test_remove_index_together_with_unique_together(self):
+        """
+        Tests that removing an index_together when a unique_together for the
+        same fields exists doesn't crash.
+        """
+        app_label = 'test_remove_index_together_bug'
+        table_name = 'test_remove_index_together_bug_pony'
+
+        # 1. Create a model with both unique_together and index_together on the same two fields.
+        project_state = ProjectState()
+        create_model_op = migrations.CreateModel(
+            'Pony',
+            [
+                ('id', models.AutoField(primary_key=True)),
+                ('field1', models.IntegerField()),
+                ('field2', models.IntegerField()),
+            ],
+            options={
+                'unique_together': {('field1', 'field2')},
+                'index_together': {('field1', 'field2')},
+            },
+        )
+
+        # Apply the CreateModel operation to a fresh state and to the database.
+        state_after_create = project_state.clone()
+        with connection.schema_editor() as editor:
+            create_model_op.state_forwards(app_label, state_after_create)
+            create_model_op.database_forwards(app_label, editor, project_state, state_after_create)
+
+        # 2. Create an operation to delete the index_together.
+        remove_index_op = migrations.AlterIndexTogether(
+            'Pony',
+            set(),  # An empty set removes all index_together.
+        )
+
+        state_before_remove = state_after_create
+        state_after_remove = state_before_remove.clone()
+        remove_index_op.state_forwards(app_label, state_after_remove)
+
+        # 3. Apply the AlterIndexTogether operation. This is the step that fails.
+        # It raises a ValueError because _delete_composed_index finds two constraints.
+        # When the bug is fixed, this will execute without error.
+        with connection.schema_editor() as editor:
+            remove_index_op.database_forwards(
+                app_label,
+                editor,
+                state_before_remove,
+                state_after_remove
+            )
+
+        # 4. Assert that the final state is correct after the fix.
+        # The test will fail before this point if the bug is present.
+        with connection.cursor() as cursor:
+            constraints = connection.introspection.get_constraints(cursor, table_name)
+
+        # The unique constraint should still exist.
+        unique_constraints = {
+            name: c for name, c in constraints.items()
+            if c['unique'] and not c['primary_key'] and c['columns'] == ['field1', 'field2']
+        }
+        self.assertEqual(len(unique_constraints), 1)
+
+        # The separate non-unique index should be gone.
+        indexes = {
+            name: c for name, c in constraints.items()
+            if c['index'] and not c['unique']
+        }
+        self.assertEqual(len(indexes), 0)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/base/schema\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_alter_index_together
cat coverage.cover
git checkout 447980e72ac01da1594dd3373a03ba40b7ee6f80
git apply /root/pre_state.patch
