#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5e04e84d67da8163f365e9f5fcd169e2630e2873 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5e04e84d67da8163f365e9f5fcd169e2630e2873
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/schema/test_create_unique_sql.py b/tests/schema/test_create_unique_sql.py
new file mode 100644
index 0000000000..861d8a6159
--- /dev/null
+++ b/tests/schema/test_create_unique_sql.py
@@ -0,0 +1,30 @@
+from django.db import connection, models
+from django.test import TestCase
+from django.test.utils import isolate_apps
+
+
+@isolate_apps('schema')
+class SchemaEditorDDLReferenceTests(TestCase):
+    def test_create_unique_sql_references_column(self):
+        """
+        A Statement created by _create_unique_sql() should correctly
+        reference the columns of a table.
+        """
+        class Author(models.Model):
+            name = models.CharField(max_length=255)
+
+            class Meta:
+                app_label = 'schema'
+
+        editor = connection.schema_editor()
+        model = Author
+        columns = [model._meta.get_field('name').column]
+        # Providing a name is required to reveal the bug, otherwise IndexName
+        # is used, which works correctly and hides the issue in the Columns
+        # part of the statement.
+        statement = editor._create_unique_sql(
+            model, columns, name='my_unique_constraint'
+        )
+        self.assertTrue(
+            statement.references_column(model._meta.db_table, columns[0])
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/base/schema\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 schema.test_create_unique_sql
cat coverage.cover
git checkout 5e04e84d67da8163f365e9f5fcd169e2630e2873
git apply /root/pre_state.patch
