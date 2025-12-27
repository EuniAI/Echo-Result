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
diff --git a/tests/schema/test_constraints.py b/tests/schema/test_constraints.py
new file mode 100644
index 0000000000..5298b26a20
--- /dev/null
+++ b/tests/schema/test_constraints.py
@@ -0,0 +1,61 @@
+import unittest
+
+from django.db import connection
+from django.db.models import CharField, Model
+from django.test import TransactionTestCase, skipUnlessDBFeature
+from django.test.utils import isolate_apps
+
+
+class SchemaTests(TransactionTestCase):
+    available_apps = []
+
+    def setUp(self):
+        self.isolated_local_models = []
+        super().setUp()
+
+    def tearDown(self):
+        with connection.schema_editor() as editor:
+            for model in self.isolated_local_models:
+                editor.delete_model(model)
+        super().tearDown()
+
+    def get_constraints(self, table):
+        """Helper method to get constraints for a table."""
+        with connection.cursor() as cursor:
+            return connection.introspection.get_constraints(cursor, table)
+
+    @isolate_apps("schema")
+    @skipUnlessDBFeature("allows_multiple_constraints_on_same_fields")
+    def test_drop_unique_together_with_unique_true_on_same_field(self):
+        """
+        Tests dropping a unique_together constraint on a field that also has
+        unique=True.
+        """
+        class Foo(Model):
+            name = CharField(max_length=255, unique=True)
+
+            class Meta:
+                app_label = "schema"
+                # This creates a second unique constraint on `name`.
+                unique_together = [["name"]]
+
+        self.isolated_local_models.append(Foo)
+        with connection.schema_editor() as editor:
+            editor.create_model(Foo)
+
+        # On unpatched code, this should raise a ValueError because
+        # _delete_composed_index finds two unique constraints (one from
+        # unique=True, one from unique_together) and doesn't know which
+        # to delete.
+        with connection.schema_editor() as editor:
+            editor.alter_unique_together(Foo, [["name"]], [])
+
+        # After dropping unique_together, the unique constraint from the
+        # `unique=True` on the field should remain.
+        constraints = self.get_constraints(Foo._meta.db_table)
+        unique_on_name = [
+            name
+            for name, details in constraints.items()
+            if details["columns"] == ["name"] and details["unique"]
+        ]
+        self.assertEqual(len(unique_on_name), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/base/schema\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 schema.test_constraints
cat coverage.cover
git checkout ce69e34bd646558bb44ea92cecfd98b345a0b3e0
git apply /root/pre_state.patch
