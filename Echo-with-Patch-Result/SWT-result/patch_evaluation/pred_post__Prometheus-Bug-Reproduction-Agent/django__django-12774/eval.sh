#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 67f9d076cfc1858b94f9ed6d1a5ce2327dcc8d0d >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 67f9d076cfc1858b94f9ed6d1a5ce2327dcc8d0d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/query.py b/django/db/models/query.py
--- a/django/db/models/query.py
+++ b/django/db/models/query.py
@@ -689,7 +689,17 @@ def in_bulk(self, id_list=None, *, field_name='pk'):
         """
         assert not self.query.is_sliced, \
             "Cannot use 'limit' or 'offset' with in_bulk"
-        if field_name != 'pk' and not self.model._meta.get_field(field_name).unique:
+        opts = self.model._meta
+        unique_fields = [
+            constraint.fields[0]
+            for constraint in opts.total_unique_constraints
+            if len(constraint.fields) == 1
+        ]
+        if (
+            field_name != 'pk' and
+            not opts.get_field(field_name).unique and
+            field_name not in unique_fields
+        ):
             raise ValueError("in_bulk()'s field_name must be a unique field but %r isn't." % field_name)
         if id_list is not None:
             if not id_list:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/queries/test_ticket_29705.py b/tests/queries/test_ticket_29705.py
new file mode 100644
index 0000000000..6b6855f617
--- /dev/null
+++ b/tests/queries/test_ticket_29705.py
@@ -0,0 +1,42 @@
+from django.db import models
+from django.test import TestCase
+
+
+class ArticleFor29705(models.Model):
+    """
+    A model with a UniqueConstraint on a field, but without `unique=True`.
+    This is used to test the fix for ticket #29705.
+    """
+    slug = models.CharField(max_length=255)
+
+    class Meta:
+        # Assign to an existing app from the test suite to ensure it's picked up.
+        app_label = 'queries'
+        constraints = [
+            models.UniqueConstraint(fields=['slug'], name='queries_articlefor29705_slug_unq'),
+        ]
+
+
+class InBulkWithUniqueConstraintTest(TestCase):
+    """
+    Tests for QuerySet.in_bulk() with a UniqueConstraint.
+    """
+    @classmethod
+    def setUpTestData(cls):
+        cls.article = ArticleFor29705.objects.create(slug='test-slug-29705')
+
+    def test_in_bulk_on_field_with_unique_constraint(self):
+        """
+        in_bulk() should work on a field that has a UniqueConstraint,
+        even if the field itself doesn't have `unique=True`.
+        """
+        # Before the fix, this call raises a ValueError because 'slug' is not
+        # considered unique. The test is expected to fail with this unhandled
+        # exception, which correctly demonstrates the bug.
+        # After the fix is applied, this line should execute without error.
+        articles = ArticleFor29705.objects.in_bulk(field_name='slug')
+
+        # These assertions will only be reached if the ValueError is not raised.
+        # They verify that the bug is fixed and the method returns the correct result.
+        self.assertIn('test-slug-29705', articles)
+        self.assertEqual(articles['test-slug-29705'].pk, self.article.pk)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_ticket_29705
cat coverage.cover
git checkout 67f9d076cfc1858b94f9ed6d1a5ce2327dcc8d0d
git apply /root/pre_state.patch
