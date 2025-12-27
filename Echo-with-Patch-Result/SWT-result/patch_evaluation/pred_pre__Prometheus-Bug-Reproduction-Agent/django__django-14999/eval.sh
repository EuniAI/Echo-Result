#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a754b82dac511475b6276039471ccd17cc64aeb8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a754b82dac511475b6276039471ccd17cc64aeb8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_rename_model_db_table_noop.py b/tests/migrations/test_rename_model_db_table_noop.py
new file mode 100644
index 0000000000..7abecb7eae
--- /dev/null
+++ b/tests/migrations/test_rename_model_db_table_noop.py
@@ -0,0 +1,112 @@
+from django.core.exceptions import FieldDoesNotExist
+from django.db import (
+    IntegrityError, connection, migrations, models, transaction,
+)
+from django.db.migrations.migration import Migration
+from django.db.migrations.operations.fields import FieldOperation
+from django.db.migrations.state import ModelState, ProjectState
+from django.db.models.functions import Abs
+from django.db.transaction import atomic
+from django.test import SimpleTestCase, override_settings, skipUnlessDBFeature
+from django.test.utils import CaptureQueriesContext
+
+from .models import FoodManager, FoodQuerySet, UnicodeModel
+from .test_base import OperationTestBase
+
+
+class Mixin:
+    pass
+
+
+class OperationTests(OperationTestBase):
+    """
+    Tests running the operations and making sure they do what they say they do.
+    Each test looks at their state changing, and then their database operation -
+    both forwards and backwards.
+    """
+
+    def test_rename_model_with_db_table_noop(self):
+        """
+        A RenameModel operation on a model with db_table set should be a no-op
+        if the db_table doesn't change.
+        """
+        app_label = 'test_rmdbt_noop'
+        # Initial state with Pony (with custom db_table) and Rider (with FK).
+        operations = [
+            migrations.CreateModel(
+                'Pony',
+                [('id', models.AutoField(primary_key=True))],
+                options={'db_table': 'pony_table'},
+            ),
+            migrations.CreateModel(
+                'Rider',
+                [
+                    ('id', models.AutoField(primary_key=True)),
+                    ('pony', models.ForeignKey('Pony', models.CASCADE)),
+                ],
+            ),
+        ]
+        project_state = self.apply_operations(app_label, ProjectState(), operations)
+
+        # The RenameModel operation to test.
+        operation = migrations.RenameModel('Pony', 'Horse')
+        # Get the state after the model is renamed.
+        new_state = project_state.clone()
+        operation.state_forwards(app_label, new_state)
+
+        # Verify that the db_table is preserved in the model's state.
+        self.assertEqual(
+            project_state.apps.get_model(app_label, 'Pony')._meta.db_table,
+            'pony_table'
+        )
+        self.assertEqual(
+            new_state.apps.get_model(app_label, 'Horse')._meta.db_table,
+            'pony_table'
+        )
+
+        # Apply the operation to the database and capture queries.
+        with CaptureQueriesContext(connection) as cqc:
+            with connection.schema_editor() as editor:
+                operation.database_forwards(app_label, editor, project_state, new_state)
+        # Before the fix, this generates queries to drop and recreate the
+        # foreign key. With the fix, it should be a no-op.
+        self.assertEqual(len(cqc.captured_queries), 0)
+
+    def test_create_model(self):
+        """
+        Tests the CreateModel operation.
+        Most other tests use this operation as part of setup, so check failures here first.
+        """
+        operation = migrations.CreateModel(
+            "Pony",
+            [
+                ("id", models.AutoField(primary_key=True)),
+                ("pink", models.IntegerField(default=1)),
+            ],
+        )
+        self.assertEqual(operation.describe(), "Create model Pony")
+        self.assertEqual(operation.migration_name_fragment, 'pony')
+        # Test the state alteration
+        project_state = ProjectState()
+        new_state = project_state.clone()
+        operation.state_forwards("test_crmo", new_state)
+        self.assertEqual(new_state.models["test_crmo", "pony"].name, "Pony")
+        self.assertEqual(len(new_state.models["test_crmo", "pony"].fields), 2)
+        # Test the database alteration
+        self.assertTableNotExists("test_crmo_pony")
+        with connection.schema_editor() as editor:
+            operation.database_forwards("test_crmo", editor, project_state, new_state)
+        self.assertTableExists("test_crmo_pony")
+        # And test reversal
+        with connection.schema_editor() as editor:
+            operation.database_backwards("test_crmo", editor, new_state, project_state)
+        self.assertTableNotExists("test_crmo_pony")
+        # And deconstruction
+        definition = operation.deconstruct()
+        self.assertEqual(definition[0], "CreateModel")
+        self.assertEqual(definition[1], [])
+        self.assertEqual(sorted(definition[2]), ["fields", "name"])
+        # And default manager not in set
+        operation = migrations.CreateModel("Foo", fields=[], managers=[("objects", models.Manager())])
+        definition = operation.deconstruct()
+        self.assertNotIn('managers', definition[2])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/operations/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_rename_model_db_table_noop
cat coverage.cover
git checkout a754b82dac511475b6276039471ccd17cc64aeb8
git apply /root/pre_state.patch
