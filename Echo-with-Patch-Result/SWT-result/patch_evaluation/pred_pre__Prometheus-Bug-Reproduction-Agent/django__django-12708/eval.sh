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
diff --git a/tests/schema/test_constraints.py b/tests/schema/test_constraints.py
new file mode 100644
index 0000000000..8235858951
--- /dev/null
+++ b/tests/schema/test_constraints.py
@@ -0,0 +1,53 @@
+import unittest
+
+from django.db import connection, models
+from django.test import TransactionTestCase, skipUnlessDBFeature
+from django.test.utils import isolate_apps
+
+
+class SchemaTests(TransactionTestCase):
+    available_apps = []
+
+    def get_constraints(self, table):
+        with connection.cursor() as cursor:
+            return connection.introspection.get_constraints(cursor, table)
+
+    def tearDown(self):
+        if hasattr(self, 'isolated_local_models'):
+            with connection.schema_editor() as editor:
+                for model in self.isolated_local_models:
+                    editor.delete_model(model)
+
+    @isolate_apps('schema')
+    @skipUnlessDBFeature('allows_multiple_constraints_on_same_fields')
+    def test_remove_index_together_with_unique_together(self):
+        """
+        Removing an index_together when a unique_together on the same
+        fields exists shouldn't fail.
+        """
+        class Book(models.Model):
+            title = models.CharField(max_length=255)
+            pub_date = models.DateField()
+
+            class Meta:
+                app_label = 'schema'
+                index_together = [['title', 'pub_date']]
+                unique_together = [['title', 'pub_date']]
+
+        self.isolated_local_models = [Book]
+
+        with connection.schema_editor() as editor:
+            editor.create_model(Book)
+
+        # This will raise ValueError before the fix because it finds both the
+        # index and the unique constraint.
+        with connection.schema_editor() as editor:
+            editor.alter_index_together(Book, Book._meta.index_together, [])
+
+        # Verify that the non-unique index is gone. The unique constraint
+        # should remain.
+        constraints = self.get_constraints(Book._meta.db_table).values()
+        self.assertIs(
+            any(c['index'] and not c['unique'] and c['columns'] == ['title', 'pub_date'] for c in constraints),
+            False
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/base/schema\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 schema.test_constraints
cat coverage.cover
git checkout 447980e72ac01da1594dd3373a03ba40b7ee6f80
git apply /root/pre_state.patch
