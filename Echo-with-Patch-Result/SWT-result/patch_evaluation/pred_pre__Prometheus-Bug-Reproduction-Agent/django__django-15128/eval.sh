#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD cb383753c0e0eb52306e1024d32a782549c27e61 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff cb383753c0e0eb52306e1024d32a782549c27e61
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/queries/test_or_combinator_alias_collision.py b/tests/queries/test_or_combinator_alias_collision.py
new file mode 100644
index 0000000000..7b6480bbe0
--- /dev/null
+++ b/tests/queries/test_or_combinator_alias_collision.py
@@ -0,0 +1,70 @@
+from django.db import models
+from django.db.models import Q
+from django.test import TestCase
+
+
+# Models from the bug report, prefixed to avoid name clashes.
+# They are added to the 'queries' app for the test runner to find them.
+class AliasCollisionBaz(models.Model):
+    class Meta:
+        app_label = 'queries'
+
+
+class AliasCollisionQux(models.Model):
+    bazes = models.ManyToManyField(AliasCollisionBaz, related_name='quxes')
+
+    class Meta:
+        app_label = 'queries'
+
+
+class AliasCollisionFoo(models.Model):
+    qux = models.ForeignKey(
+        AliasCollisionQux, on_delete=models.CASCADE, related_name='foos'
+    )
+
+    class Meta:
+        app_label = 'queries'
+
+
+class AliasCollisionBar(models.Model):
+    foo = models.ForeignKey(
+        AliasCollisionFoo, on_delete=models.CASCADE, related_name='bars'
+    )
+    another_foo = models.ForeignKey(
+        AliasCollisionFoo, on_delete=models.CASCADE, related_name='other_bars'
+    )
+    baz = models.ForeignKey(
+        AliasCollisionBaz, on_delete=models.CASCADE, related_name='bars'
+    )
+
+    class Meta:
+        app_label = 'queries'
+
+
+class QuerySetORCombinatorAliasCollisionTests(TestCase):
+    def test_or_combinator_alias_collision(self):
+        """
+        Regression test for an alias collision in Query.change_aliases
+        when combining querysets with `|`.
+        """
+        qux = AliasCollisionQux.objects.create()
+        baz = AliasCollisionBaz.objects.create()
+        qux.bazes.add(baz)
+
+        foo = AliasCollisionFoo.objects.create(qux=qux)
+        bar_foo = AliasCollisionFoo.objects.create(qux=qux)
+        AliasCollisionBar.objects.create(
+            foo=bar_foo, another_foo=bar_foo, baz=baz
+        )
+
+        qs1 = qux.foos.all()
+        qs2 = AliasCollisionFoo.objects.filter(
+            Q(bars__baz__in=qux.bazes.all()) |
+            Q(other_bars__baz__in=qux.bazes.all())
+        )
+
+        # The combination qs1 | qs2 triggers the bug. Before the fix, this
+        # raises an AssertionError. After the fix, it should execute and
+        # return the correct combined results.
+        combined_qs = qs1 | qs2
+        self.assertCountEqual(list(combined_qs), [foo, bar_foo])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_or_combinator_alias_collision
cat coverage.cover
git checkout cb383753c0e0eb52306e1024d32a782549c27e61
git apply /root/pre_state.patch
