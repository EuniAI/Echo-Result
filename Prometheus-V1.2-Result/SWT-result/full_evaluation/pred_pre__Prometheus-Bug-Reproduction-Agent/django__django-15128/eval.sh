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
diff --git a/tests/queries/test_qs_or_operator_alias_collision.py b/tests/queries/test_qs_or_operator_alias_collision.py
new file mode 100644
index 0000000000..88f7c14bd6
--- /dev/null
+++ b/tests/queries/test_qs_or_operator_alias_collision.py
@@ -0,0 +1,74 @@
+from django.db import models
+from django.db.models import Q
+from django.test import TestCase
+
+
+# Models inspired by the bug report to create a self-contained regression test.
+# These models are intentionally named to be unique for this test case and are
+# assigned to an existing app to ensure they are created by the test runner.
+class ChangeAliasFoo(models.Model):
+    qux = models.ForeignKey(
+        "ChangeAliasQux", on_delete=models.CASCADE, related_name="foos"
+    )
+
+    class Meta:
+        app_label = "queries"
+
+
+class ChangeAliasBar(models.Model):
+    foo = models.ForeignKey(
+        "ChangeAliasFoo", on_delete=models.CASCADE, related_name="bars"
+    )
+    another_foo = models.ForeignKey(
+        "ChangeAliasFoo", on_delete=models.CASCADE, related_name="other_bars"
+    )
+    baz = models.ForeignKey(
+        "ChangeAliasBaz", on_delete=models.CASCADE, related_name="bars"
+    )
+
+    class Meta:
+        app_label = "queries"
+
+
+class ChangeAliasBaz(models.Model):
+    class Meta:
+        app_label = "queries"
+
+
+class ChangeAliasQux(models.Model):
+    bazes = models.ManyToManyField("ChangeAliasBaz", related_name="quxes")
+
+    class Meta:
+        app_label = "queries"
+
+
+class QueryCompilerTests(TestCase):
+    """
+    Tests for the SQL query compiler, focusing on regressions and edge cases.
+    """
+
+    def test_qs_or_operator_alias_collision(self):
+        """
+        Regression test for a bug where combining querysets with the OR
+        operator (|) could lead to an AssertionError in Query.change_aliases.
+
+        This occurs when the right-hand-side queryset has sequential aliases
+        that conflict with aliases being created during the join promotion
+        process of the combination.
+        """
+        qux = ChangeAliasQux.objects.create()
+        # This queryset is a simple reverse foreign key lookup.
+        qs1 = qux.foos.all()
+        # This queryset involves multiple joins, leading to more complex aliasing.
+        # The two filters on `bars` and `other_bars` create a situation
+        # where sequential aliases are generated that can cause conflicts.
+        qs2 = ChangeAliasFoo.objects.filter(
+            Q(bars__baz__in=qux.bazes.all())
+            | Q(other_bars__baz__in=qux.bazes.all())
+        )
+
+        # The combination `qs1 | qs2` fails due to the alias collision bug,
+        # raising an AssertionError. When fixed, it should execute without error.
+        # The assertion checks for an empty result, which is correct as no
+        # ChangeAliasFoo objects have been created. This forces query evaluation.
+        self.assertQuerysetEqual(qs1 | qs2, [])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_qs_or_operator_alias_collision
cat coverage.cover
git checkout cb383753c0e0eb52306e1024d32a782549c27e61
git apply /root/pre_state.patch
