#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD bb64b99b78a579cb2f6178011a4cf9366e634438 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff bb64b99b78a579cb2f6178011a4cf9366e634438
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/migrations/operations/models.py b/django/db/migrations/operations/models.py
--- a/django/db/migrations/operations/models.py
+++ b/django/db/migrations/operations/models.py
@@ -137,11 +137,15 @@ def reduce(self, operation, app_label):
                 ),
             ]
         elif isinstance(operation, AlterModelOptions) and self.name_lower == operation.name_lower:
+            options = {**self.options, **operation.options}
+            for key in operation.ALTER_OPTION_KEYS:
+                if key not in operation.options:
+                    options.pop(key, None)
             return [
                 CreateModel(
                     self.name,
                     fields=self.fields,
-                    options={**self.options, **operation.options},
+                    options=options,
                     bases=self.bases,
                     managers=self.managers,
                 ),

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_optimizer_alter_model_options.py b/tests/migrations/test_optimizer_alter_model_options.py
new file mode 100644
index 0000000000..9f9baae73f
--- /dev/null
+++ b/tests/migrations/test_optimizer_alter_model_options.py
@@ -0,0 +1,42 @@
+from django.db import migrations, models
+from django.db.migrations.optimizer import MigrationOptimizer
+from django.test import SimpleTestCase
+
+
+class OptimizerTests(SimpleTestCase):
+    """
+    Tests the migration optimizer.
+    """
+
+    def optimize(self, operations, app_label='migrations'):
+        optimizer = MigrationOptimizer()
+        return optimizer.optimize(operations, app_label)
+
+    def assertOptimizesTo(self, operations, expected):
+        """
+        Asserts that a list of operations optimizes to another list.
+        """
+        result = self.optimize(operations)
+        self.assertEqual(
+            [op.deconstruct() for op in result],
+            [op.deconstruct() for op in expected],
+        )
+
+    def test_create_alter_model_options_unset(self):
+        """
+        Tests that AlterModelOptions with an empty options dict unsets
+        options when squashed into a CreateModel operation.
+        """
+        self.assertOptimizesTo(
+            [
+                migrations.CreateModel(
+                    'test_model',
+                    fields=[],
+                    options={'verbose_name': 'Test Models'},
+                ),
+                migrations.AlterModelOptions(name='test_model', options={}),
+            ],
+            [
+                migrations.CreateModel('test_model', fields=[], options={}),
+            ],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/operations/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_optimizer_alter_model_options
cat coverage.cover
git checkout bb64b99b78a579cb2f6178011a4cf9366e634438
git apply /root/pre_state.patch
