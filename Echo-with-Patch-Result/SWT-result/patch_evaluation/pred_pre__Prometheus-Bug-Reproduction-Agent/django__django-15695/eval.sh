#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 647480166bfe7532e8c471fef0146e3a17e6c0c9 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 647480166bfe7532e8c471fef0146e3a17e6c0c9
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_rename_unnamed_index_reapply.py b/tests/migrations/test_rename_unnamed_index_reapply.py
new file mode 100644
index 0000000000..4700276e82
--- /dev/null
+++ b/tests/migrations/test_rename_unnamed_index_reapply.py
@@ -0,0 +1,32 @@
+from django.db import connection, migrations, models
+from django.test import skipUnlessDBFeature
+
+from .test_base import OperationTestBase
+
+
+class OperationTests(OperationTestBase):
+    @skipUnlessDBFeature("can_rename_index")
+    def test_rename_unnamed_index_reapply(self):
+        """
+        RenameIndex on an unnamed index can be reversed and re-applied.
+        """
+        app_label = "test_rnunidx"
+        project_state = self.set_up_test_model(app_label, index_together=True)
+        table_name = f"{app_label}_pony"
+        operation = migrations.RenameIndex(
+            model_name="Pony",
+            new_name="new_pony_test_idx",
+            old_fields=("weight", "pink"),
+        )
+        new_state = project_state.clone()
+        operation.state_forwards(app_label, new_state)
+        # Forward.
+        with connection.schema_editor() as editor:
+            operation.database_forwards(app_label, editor, project_state, new_state)
+        # Backward.
+        with connection.schema_editor() as editor:
+            operation.database_backwards(app_label, editor, new_state, project_state)
+        # Re-apply renaming. This is the step that should crash.
+        with connection.schema_editor() as editor:
+            operation.database_forwards(app_label, editor, project_state, new_state)
+        self.assertIndexNameExists(table_name, "new_pony_test_idx")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/operations/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_rename_unnamed_index_reapply
cat coverage.cover
git checkout 647480166bfe7532e8c471fef0146e3a17e6c0c9
git apply /root/pre_state.patch
