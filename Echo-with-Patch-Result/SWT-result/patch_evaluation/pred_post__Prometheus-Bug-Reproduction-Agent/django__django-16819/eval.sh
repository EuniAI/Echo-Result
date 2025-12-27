#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0b0998dc151feb77068e2387c34cc50ef6b356ae >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0b0998dc151feb77068e2387c34cc50ef6b356ae
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/migrations/operations/models.py b/django/db/migrations/operations/models.py
--- a/django/db/migrations/operations/models.py
+++ b/django/db/migrations/operations/models.py
@@ -861,6 +861,11 @@ def describe(self):
     def migration_name_fragment(self):
         return "%s_%s" % (self.model_name_lower, self.index.name.lower())
 
+    def reduce(self, operation, app_label):
+        if isinstance(operation, RemoveIndex) and self.index.name == operation.name:
+            return []
+        return super().reduce(operation, app_label)
+
 
 class RemoveIndex(IndexOperation):
     """Remove an index from a model."""

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_optimizer_bug.py b/tests/migrations/test_optimizer_bug.py
new file mode 100644
index 0000000000..6b74b5f906
--- /dev/null
+++ b/tests/migrations/test_optimizer_bug.py
@@ -0,0 +1,90 @@
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
+    def test_add_remove_index(self):
+        """
+        AddIndex and RemoveIndex should collapse into nothing.
+        """
+        self.assertOptimizesTo(
+            [
+                migrations.AddIndex(
+                    "Pony",
+                    models.Index(fields=["weight"], name="pony_test_idx"),
+                ),
+                migrations.RemoveIndex("Pony", "pony_test_idx"),
+            ],
+            [],
+        )
+
+    def test_remove_add_index(self):
+        """
+        RemoveIndex and AddIndex should collapse into nothing.
+        """
+        self.assertOptimizesTo(
+            [
+                migrations.RemoveIndex("Pony", "pony_test_idx"),
+                migrations.AddIndex(
+                    "Pony",
+                    models.Index(fields=["weight"], name="pony_test_idx"),
+                ),
+            ],
+            [],
+        )
+
+    def test_add_rename_index(self):
+        """
+        RenameIndex should optimize into AddIndex.
+        """
+        self.assertOptimizesTo(
+            [
+                migrations.AddIndex(
+                    "Pony",
+                    models.Index(fields=["weight"], name="pony_test_idx"),
+                ),
+                migrations.RenameIndex(
+                    "Pony", old_name="pony_test_idx", new_name="pony_new_idx"
+                ),
+            ],
+            [
+                migrations.AddIndex(
+                    "Pony",
+                    models.Index(fields=["weight"], name="pony_new_idx"),
+                ),
+            ],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/operations/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_optimizer_bug
cat coverage.cover
git checkout 0b0998dc151feb77068e2387c34cc50ef6b356ae
git apply /root/pre_state.patch
