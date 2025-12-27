#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0ab58c120939093fea90822f376e1866fc714d1f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0ab58c120939093fea90822f376e1866fc714d1f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/backends/sqlite3/schema.py b/django/db/backends/sqlite3/schema.py
--- a/django/db/backends/sqlite3/schema.py
+++ b/django/db/backends/sqlite3/schema.py
@@ -324,10 +324,15 @@ def delete_model(self, model, handle_autom2m=True):
 
     def add_field(self, model, field):
         """Create a field on a model."""
-        # Fields with default values cannot by handled by ALTER TABLE ADD
-        # COLUMN statement because DROP DEFAULT is not supported in
-        # ALTER TABLE.
-        if not field.null or self.effective_default(field) is not None:
+        if (
+            # Primary keys and unique fields are not supported in ALTER TABLE
+            # ADD COLUMN.
+            field.primary_key or field.unique or
+            # Fields with default values cannot by handled by ALTER TABLE ADD
+            # COLUMN statement because DROP DEFAULT is not supported in
+            # ALTER TABLE.
+            not field.null or self.effective_default(field) is not None
+        ):
             self._remake_table(model, create_field=field)
         else:
             super().add_field(model, field)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_add_nullable_one_to_one_field.py b/tests/migrations/test_add_nullable_one_to_one_field.py
new file mode 100644
index 0000000000..38f6d8301f
--- /dev/null
+++ b/tests/migrations/test_add_nullable_one_to_one_field.py
@@ -0,0 +1,54 @@
+import unittest
+
+from django.db import connection, migrations, models
+from django.db.migrations.state import ProjectState
+from django.test import skipUnlessDBFeature
+
+from .test_base import OperationTestBase
+
+
+class OperationsTests(OperationTestBase):
+    @unittest.skipUnless(connection.vendor == 'sqlite', 'SQLite-specific bug')
+    def test_add_nullable_one_to_one_field(self):
+        """
+        Test AddField operation for a nullable OneToOneField on SQLite.
+        """
+        app_label = 'test_add_nullable_o2o'
+        # Initial state: two models, Author and Book.
+        project_state = self.apply_operations(
+            app_label,
+            ProjectState(),
+            operations=[
+                migrations.CreateModel(
+                    'Author',
+                    [('id', models.AutoField(primary_key=True))],
+                ),
+                migrations.CreateModel(
+                    'Book',
+                    [('id', models.AutoField(primary_key=True))],
+                ),
+            ],
+        )
+
+        # The operation that causes the crash on SQLite.
+        operation = migrations.AddField(
+            model_name='Book',
+            name='author',
+            field=models.OneToOneField(
+                'Author',
+                on_delete=models.SET_NULL,
+                blank=True,
+                null=True,
+            ),
+        )
+
+        # This should raise OperationalError: Cannot add a UNIQUE column on SQLite.
+        # When the bug is fixed, this will pass.
+        new_state = project_state.clone()
+        operation.state_forwards(app_label, new_state)
+        with connection.schema_editor() as editor:
+            operation.database_forwards(app_label, editor, project_state, new_state)
+
+        # The minimal assertion is to check that the column was created. This
+        # will only be reached if the operation doesn't crash.
+        self.assertColumnExists('%s_book' % app_label, 'author_id')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/sqlite3/schema\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_add_nullable_one_to_one_field
cat coverage.cover
git checkout 0ab58c120939093fea90822f376e1866fc714d1f
git apply /root/pre_state.patch
