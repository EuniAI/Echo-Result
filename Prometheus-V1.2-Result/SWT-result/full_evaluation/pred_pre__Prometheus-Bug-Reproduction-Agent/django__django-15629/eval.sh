#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 694cf458f16b8d340a3195244196980b2dec34fd >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 694cf458f16b8d340a3195244196980b2dec34fd
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/schema/test_collation.py b/tests/schema/test_collation.py
new file mode 100644
index 0000000000..7b0140b278
--- /dev/null
+++ b/tests/schema/test_collation.py
@@ -0,0 +1,76 @@
+import unittest
+
+from django.db import connection
+from django.db.models import (
+    AutoField,
+    CASCADE,
+    CharField,
+    ForeignKey,
+    Model,
+)
+from django.test import TransactionTestCase, skipUnlessDBFeature
+from django.test.utils import isolate_apps
+
+
+class CollationTests(TransactionTestCase):
+    available_apps = []
+
+    def setUp(self):
+        self.isolated_local_models = []
+
+    def tearDown(self):
+        if self.isolated_local_models:
+            with connection.schema_editor() as editor:
+                for model in self.isolated_local_models:
+                    editor.delete_model(model)
+
+    def get_column_collation(self, table, column):
+        with connection.cursor() as cursor:
+            return next(
+                f.collation
+                for f in connection.introspection.get_table_description(cursor, table)
+                if f.name == column
+            )
+
+    @isolate_apps("schema")
+    @skipUnlessDBFeature("supports_collation_on_charfield", "supports_foreign_keys")
+    def test_pk_alter_db_collation_propagation(self):
+        """
+        Collation on a primary key is propagated to referring ForeignKey
+        columns on alter_field().
+        """
+        collation = connection.features.test_collations.get("non_default")
+        if not collation:
+            self.skipTest("This backend does not support non-default collations.")
+
+        class Parent(Model):
+            id = AutoField(primary_key=True)
+
+            class Meta:
+                app_label = "schema"
+
+        class Child(Model):
+            parent = ForeignKey(Parent, on_delete=CASCADE)
+
+            class Meta:
+                app_label = "schema"
+
+        self.isolated_local_models = [Parent, Child]
+
+        with connection.schema_editor() as editor:
+            editor.create_model(Parent)
+            editor.create_model(Child)
+
+        old_pk = Parent._meta.get_field("id")
+        new_pk = CharField(primary_key=True, max_length=22, db_collation=collation)
+        new_pk.set_attributes_from_name("id")
+        new_pk.model = Parent
+
+        with connection.schema_editor() as editor:
+            editor.alter_field(Parent, old_pk, new_pk)
+
+        child_fk_column = Child._meta.get_field("parent").column
+        self.assertEqual(
+            self.get_column_collation(Child._meta.db_table, child_fk_column),
+            collation,
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/oracle/features\.py|django/db/models/fields/related\.py|django/db/backends/base/schema\.py|django/db/backends/sqlite3/schema\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 schema.test_collation
cat coverage.cover
git checkout 694cf458f16b8d340a3195244196980b2dec34fd
git apply /root/pre_state.patch
