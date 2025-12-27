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
diff --git a/tests/migrations/test_add_nullable_field.py b/tests/migrations/test_add_nullable_field.py
new file mode 100644
index 0000000000..4b2e165183
--- /dev/null
+++ b/tests/migrations/test_add_nullable_field.py
@@ -0,0 +1,41 @@
+import unittest
+
+from django.db import connection, migrations, models
+from django.test import skipUnlessDBFeature
+
+from .test_base import OperationTestBase
+
+
+class AddNullableFieldTests(OperationTestBase):
+    @unittest.skipUnless(connection.vendor == "sqlite", "SQLite-specific test")
+    def test_add_nullable_one_to_one_field(self):
+        """
+        Tests adding a nullable OneToOneField on SQLite.
+        """
+        app_label = "test_add_nullable_o2o"
+        project_state = self.set_up_test_model(app_label, second_model=True)
+        # Add some data to make sure the table isn't empty.
+        Pony = project_state.apps.get_model(app_label, "Pony")
+        Pony.objects.create(weight=42)
+
+        operation = migrations.AddField(
+            model_name="Pony",
+            name="stable",
+            field=models.OneToOneField(
+                "Stable",
+                on_delete=models.SET_NULL,
+                blank=True,
+                null=True,
+                related_name="pony",
+            ),
+        )
+
+        new_state = project_state.clone()
+        operation.state_forwards(app_label, new_state)
+
+        # This will fail with "OperationalError: Cannot add a UNIQUE column"
+        # on SQLite if the backend doesn't remake the table.
+        with connection.schema_editor() as editor:
+            operation.database_forwards(app_label, editor, project_state, new_state)
+
+        self.assertColumnExists("%s_pony" % app_label, "stable_id")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/sqlite3/schema\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_add_nullable_field
cat coverage.cover
git checkout 0ab58c120939093fea90822f376e1866fc714d1f
git apply /root/pre_state.patch
