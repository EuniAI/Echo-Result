#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0ab58c120939093fea90822f376e1866fc714d1f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0ab58c120939093fea90822f376e1866fc714d1f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_optimizer_alter_together.py b/tests/migrations/test_optimizer_alter_together.py
new file mode 100644
index 0000000000..ba9a58517c
--- /dev/null
+++ b/tests/migrations/test_optimizer_alter_together.py
@@ -0,0 +1,73 @@
+from django.db import migrations
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
+    def assertDoesNotOptimize(self, operations, **kwargs):
+        self.assertOptimizesTo(operations, operations, **kwargs)
+
+    def test_alter_together_optimize(self):
+        """
+        AlterUniqueTogether and AlterIndexTogether can be optimized when
+        separated by other AlterFooTogether operations.
+        """
+        self.assertOptimizesTo(
+            [
+                migrations.AlterUniqueTogether(
+                    name='MyModel',
+                    unique_together=set(),
+                ),
+                migrations.AlterIndexTogether(
+                    name='MyModel',
+                    index_together=set(),
+                ),
+                migrations.AlterUniqueTogether(
+                    name='MyModel',
+                    unique_together={('col',)},
+                ),
+                migrations.AlterIndexTogether(
+                    name='MyModel',
+                    index_together={('col',)},
+                ),
+            ],
+            [
+                migrations.AlterUniqueTogether(
+                    name='MyModel',
+                    unique_together={('col',)},
+                ),
+                migrations.AlterIndexTogether(
+                    name='MyModel',
+                    index_together={('col',)},
+                ),
+            ],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/operations/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_optimizer_alter_together
cat coverage.cover
git checkout 0ab58c120939093fea90822f376e1866fc714d1f
git apply /root/pre_state.patch
