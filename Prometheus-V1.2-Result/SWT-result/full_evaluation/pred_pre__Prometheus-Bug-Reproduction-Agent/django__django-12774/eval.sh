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
diff --git a/tests/lookup/test_in_bulk_unique_constraint.py b/tests/lookup/test_in_bulk_unique_constraint.py
new file mode 100644
index 0000000000..b5c341695a
--- /dev/null
+++ b/tests/lookup/test_in_bulk_unique_constraint.py
@@ -0,0 +1,30 @@
+from django.db import models
+from django.test import TestCase
+
+
+class ArticleWithSlugConstraint(models.Model):
+    headline = models.CharField(max_length=100)
+    slug = models.CharField(max_length=255)
+
+    class Meta:
+        app_label = 'lookup'
+        constraints = [
+            models.UniqueConstraint(fields=['slug'], name='%(app_label)s_%(class)s_slug_unq')
+        ]
+
+    def __str__(self):
+        return self.headline
+
+
+class InBulkUniqueConstraintTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.a1 = ArticleWithSlugConstraint.objects.create(headline='Article 1', slug='a1')
+        cls.a2 = ArticleWithSlugConstraint.objects.create(headline='Article 2', slug='a2')
+
+    def test_in_bulk_on_field_with_unique_constraint(self):
+        """
+        in_bulk() should work on a field with a UniqueConstraint.
+        """
+        articles = ArticleWithSlugConstraint.objects.in_bulk(field_name='slug')
+        self.assertEqual(articles, {'a1': self.a1, 'a2': self.a2})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 lookup.test_in_bulk_unique_constraint
cat coverage.cover
git checkout 67f9d076cfc1858b94f9ed6d1a5ce2327dcc8d0d
git apply /root/pre_state.patch
