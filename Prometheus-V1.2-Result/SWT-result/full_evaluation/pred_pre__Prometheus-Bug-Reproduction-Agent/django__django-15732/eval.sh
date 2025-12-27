#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ce69e34bd646558bb44ea92cecfd98b345a0b3e0 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ce69e34bd646558bb44ea92cecfd98b345a0b3e0
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_alter_unique_together.py b/tests/migrations/test_alter_unique_together.py
new file mode 100644
index 0000000000..bd2bdde5e7
--- /dev/null
+++ b/tests/migrations/test_alter_unique_together.py
@@ -0,0 +1,52 @@
+from django.db import connection, migrations, models
+from django.db.migrations.state import ProjectState
+from django.test import skipUnlessDBFeature
+
+from .test_base import OperationTestBase
+
+
+class OperationTests(OperationTestBase):
+    @skipUnlessDBFeature("allows_multiple_constraints_on_same_fields")
+    def test_remove_unique_together_on_field_with_unique_true(self):
+        """
+        Tests removing a unique_together constraint on a field that also has
+        a unique=True constraint.
+        """
+        app_label = "test_rut_suf"
+        project_state = ProjectState()
+        # Define a model with a field that has both unique=True and is in a
+        # unique_together. This creates two unique constraints on the same
+        # column on some backends, which is the condition for the bug.
+        create_op = migrations.CreateModel(
+            "Pony",
+            fields=[
+                ("id", models.AutoField(primary_key=True)),
+                ("name", models.CharField(max_length=50, unique=True)),
+            ],
+            options={"unique_together": {("name",)}},
+        )
+        initial_state = project_state.clone()
+        create_op.state_forwards(app_label, initial_state)
+        with connection.schema_editor() as editor:
+            create_op.database_forwards(app_label, editor, project_state, initial_state)
+
+        # The test is expected to fail inside this try block. The finally
+        # block ensures the model's table is cleaned up afterward.
+        try:
+            # This operation will attempt to remove the unique_together
+            # constraint. It is expected to fail with a ValueError because
+            # Django's schema editor will find two unique constraints on the
+            # "name" column and won't know which one to remove.
+            alter_op = migrations.AlterUniqueTogether("Pony", set())
+            altered_state = initial_state.clone()
+            alter_op.state_forwards(app_label, altered_state)
+            with connection.schema_editor() as editor:
+                alter_op.database_forwards(
+                    app_label, editor, initial_state, altered_state
+                )
+        finally:
+            # Clean up the table.
+            with connection.schema_editor() as editor:
+                create_op.database_backwards(
+                    app_label, editor, initial_state, project_state
+                )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/base/schema\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_alter_unique_together
cat coverage.cover
git checkout ce69e34bd646558bb44ea92cecfd98b345a0b3e0
git apply /root/pre_state.patch
