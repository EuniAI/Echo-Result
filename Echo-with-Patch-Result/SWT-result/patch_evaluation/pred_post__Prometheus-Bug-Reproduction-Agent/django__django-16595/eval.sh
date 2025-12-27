#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f9fe062de5fc0896d6bbbf3f260b5c44473b3c77 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f9fe062de5fc0896d6bbbf3f260b5c44473b3c77
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/migrations/operations/fields.py b/django/db/migrations/operations/fields.py
--- a/django/db/migrations/operations/fields.py
+++ b/django/db/migrations/operations/fields.py
@@ -247,9 +247,9 @@ def migration_name_fragment(self):
         return "alter_%s_%s" % (self.model_name_lower, self.name_lower)
 
     def reduce(self, operation, app_label):
-        if isinstance(operation, RemoveField) and self.is_same_field_operation(
-            operation
-        ):
+        if isinstance(
+            operation, (AlterField, RemoveField)
+        ) and self.is_same_field_operation(operation):
             return [operation]
         elif (
             isinstance(operation, RenameField)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_migrations_optimizer.py b/tests/test_migrations_optimizer.py
new file mode 100644
index 0000000000..3ea64e5582
--- /dev/null
+++ b/tests/test_migrations_optimizer.py
@@ -0,0 +1,73 @@
+import unittest
+from django.db import migrations, models
+from django.db.migrations.optimizer import MigrationOptimizer
+from django.db.migrations.serializer import serializer_factory
+from django.test import SimpleTestCase
+
+
+class OptimizerTests(SimpleTestCase):
+    """
+    Tests the migration optimizer.
+    """
+
+    def optimize(self, operations, app_label):
+        """
+        Handy shortcut for getting results + number of loops
+        """
+        optimizer = MigrationOptimizer()
+        return optimizer.optimize(operations, app_label), optimizer._iterations
+
+    def serialize(self, value):
+        return serializer_factory(value).serialize()[0]
+
+    def assertOptimizesTo(
+        self, operations, expected, exact=None, less_than=None, app_label=None
+    ):
+        result, iterations = self.optimize(operations, app_label or "migrations")
+        result = [self.serialize(f) for f in result]
+        expected = [self.serialize(f) for f in expected]
+        self.assertEqual(expected, result)
+        if exact is not None and iterations != exact:
+            raise self.failureException(
+                "Optimization did not take exactly %s iterations (it took %s)"
+                % (exact, iterations)
+            )
+        if less_than is not None and iterations >= less_than:
+            raise self.failureException(
+                "Optimization did not take less than %s iterations (it took %s)"
+                % (less_than, iterations)
+            )
+
+    def test_alter_field_alter_field(self):
+        """
+        Multiple AlterField operations should be optimized into a single one.
+        """
+        operations = [
+            migrations.AlterField(
+                model_name="Book",
+                name="title",
+                field=models.CharField(max_length=128, null=True),
+            ),
+            migrations.AlterField(
+                model_name="Book",
+                name="title",
+                field=models.CharField(max_length=128, null=True, help_text="help"),
+            ),
+            migrations.AlterField(
+                model_name="Book",
+                name="title",
+                field=models.CharField(
+                    max_length=128, null=True, help_text="help", default=None
+                ),
+            ),
+        ]
+        expected = [
+            migrations.AlterField(
+                model_name="Book",
+                name="title",
+                field=models.CharField(
+                    max_length=128, null=True, help_text="help", default=None
+                ),
+            ),
+        ]
+        self.assertOptimizesTo(operations, expected, app_label="books")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/operations/fields\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_migrations_optimizer
cat coverage.cover
git checkout f9fe062de5fc0896d6bbbf3f260b5c44473b3c77
git apply /root/pre_state.patch
