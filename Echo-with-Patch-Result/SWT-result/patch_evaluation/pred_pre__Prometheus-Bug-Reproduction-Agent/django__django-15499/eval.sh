#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD d90e34c61b27fba2527834806639eebbcfab9631 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff d90e34c61b27fba2527834806639eebbcfab9631
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_optimizer_managers.py b/tests/migrations/test_optimizer_managers.py
new file mode 100644
index 0000000000..41e5f9a8dd
--- /dev/null
+++ b/tests/migrations/test_optimizer_managers.py
@@ -0,0 +1,50 @@
+from django.db import migrations, models
+from django.test import SimpleTestCase
+from django.db.migrations.optimizer import MigrationOptimizer
+from django.db.migrations.serializer import serializer_factory
+
+
+class EmptyManager(models.Manager):
+    use_in_migrations = True
+
+
+class OptimizerTests(SimpleTestCase):
+    """
+    Tests the migration optimizer.
+    """
+
+    def optimize(self, operations, app_label=None):
+        """
+        Handy shortcut for getting results.
+        """
+        optimizer = MigrationOptimizer()
+        return optimizer.optimize(operations, app_label or "migrations")
+
+    def serialize(self, value):
+        return serializer_factory(value).serialize()[0]
+
+    def assertOptimizesTo(self, operations, expected, app_label=None):
+        result = self.optimize(operations, app_label)
+        self.assertEqual(
+            [self.serialize(op) for op in expected],
+            [self.serialize(op) for op in result],
+        )
+
+    def test_create_alter_model_managers(self):
+        """
+        CreateModel should absorb AlterModelManagers.
+        """
+        custom_manager = [("objects", EmptyManager())]
+        self.assertOptimizesTo(
+            [
+                migrations.CreateModel("Foo", fields=[]),
+                migrations.AlterModelManagers(
+                    name="Foo", managers=custom_manager
+                ),
+            ],
+            [
+                migrations.CreateModel(
+                    "Foo", fields=[], managers=custom_manager
+                ),
+            ],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/operations/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_optimizer_managers
cat coverage.cover
git checkout d90e34c61b27fba2527834806639eebbcfab9631
git apply /root/pre_state.patch
