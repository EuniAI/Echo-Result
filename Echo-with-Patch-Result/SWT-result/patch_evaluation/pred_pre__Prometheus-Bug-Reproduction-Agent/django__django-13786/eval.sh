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
diff --git a/tests/migrations/test_optimizer_emptying_options.py b/tests/migrations/test_optimizer_emptying_options.py
new file mode 100644
index 0000000000..f824a07d8b
--- /dev/null
+++ b/tests/migrations/test_optimizer_emptying_options.py
@@ -0,0 +1,48 @@
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
+    def assertOptimizesTo(self, operations, expected, exact=None, less_than=None, app_label=None):
+        result, iterations = self.optimize(operations, app_label or 'migrations')
+        result = [self.serialize(f) for f in result]
+        expected = [self.serialize(f) for f in expected]
+        self.assertEqual(expected, result)
+        if exact is not None and iterations != exact:
+            raise self.failureException(
+                "Optimization did not take exactly %s iterations (it took %s)" % (exact, iterations)
+            )
+        if less_than is not None and iterations >= less_than:
+            raise self.failureException(
+                "Optimization did not take less than %s iterations (it took %s)" % (less_than, iterations)
+            )
+
+    def test_create_alter_model_options_emptying(self):
+        """
+        AlterModelOptions can empty the options of a CreateModel.
+        """
+        self.assertOptimizesTo(
+            [
+                migrations.CreateModel('Foo', fields=[], options={'verbose_name': 'Foooo'}),
+                migrations.AlterModelOptions(name='Foo', options={}),
+            ],
+            [
+                migrations.CreateModel('Foo', fields=[]),
+            ],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/operations/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_optimizer_emptying_options
cat coverage.cover
git checkout bb64b99b78a579cb2f6178011a4cf9366e634438
git apply /root/pre_state.patch
