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
index 0000000000..45446bc2a4
--- /dev/null
+++ b/tests/migrations/test_alter_field.py
@@ -0,0 +1,28 @@
+from django.db import connection, migrations, models
+from django.test.utils import CaptureQueriesContext
+
+from .test_base import OperationTestBase
+
+
+class OperationTests(OperationTestBase):
+    def test_alter_field_choices_noop(self):
+        """
+        Changing the 'choices' option on a field should be a no-op.
+        """
+        app_label = "test_alter_field_choices_noop"
+        project_state = self.set_up_test_model(app_label)
+        operation = migrations.AlterField(
+            "Pony",
+            "pink",
+            models.IntegerField(default=3, choices=[(1, "hot pink")]),
+        )
+
+        new_state = project_state.clone()
+        operation.state_forwards(app_label, new_state)
+
+        # Test that the database alteration is a no-op.
+        with connection.schema_editor() as editor:
+            with self.assertNumQueries(0):
+                operation.database_forwards(
+                    app_label, editor, project_state, new_state
+                )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py|django/db/backends/base/schema\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_alter_field
cat coverage.cover
git checkout 6991880109e35c879b71b7d9d9c154baeec12b89
git apply /root/pre_state.patch
