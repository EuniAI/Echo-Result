#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD beb7ddbcee03270e833b2f74927ccfc8027aa693 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff beb7ddbcee03270e833b2f74927ccfc8027aa693
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/aggregation_regress/test_aggregate_after_annotate.py b/tests/aggregation_regress/test_aggregate_after_annotate.py
new file mode 100644
index 0000000000..34bea9d874
--- /dev/null
+++ b/tests/aggregation_regress/test_aggregate_after_annotate.py
@@ -0,0 +1,47 @@
+import datetime
+from decimal import Decimal
+
+from django.db.models import F, Sum
+from django.test import TestCase
+
+from .models import Author, Book, Publisher
+
+
+class AggregateTestCase(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.a1 = Author.objects.create(name='Adrian Holovaty', age=34)
+        cls.a2 = Author.objects.create(name='Jacob Kaplan-Moss', age=35)
+        cls.a3 = Author.objects.create(name='Brad Dayley', age=45)
+        cls.a4 = Author.objects.create(name='James Bennett', age=29)
+        cls.a5 = Author.objects.create(name='Jeffrey Forcier', age=37)
+        cls.a6 = Author.objects.create(name='Paul Bissex', age=29)
+        cls.a7 = Author.objects.create(name='Wesley J. Chun', age=25)
+        cls.a8 = Author.objects.create(name='Peter Norvig', age=57)
+        cls.a9 = Author.objects.create(name='Stuart Russell', age=46)
+
+        cls.p1 = Publisher.objects.create(name='Apress', num_awards=3)
+        cls.p2 = Publisher.objects.create(name='Sams', num_awards=1)
+        cls.p3 = Publisher.objects.create(name='Prentice Hall', num_awards=7)
+        cls.p4 = Publisher.objects.create(name='Morgan Kaufmann', num_awards=9)
+
+        cls.b1 = Book.objects.create(
+            isbn='159059725', name='The Definitive Guide to Django: Web Development Done Right',
+            pages=447, rating=4.5, price=Decimal('30.00'), contact=cls.a1, publisher=cls.p1,
+            pubdate=datetime.date(2007, 12, 6)
+        )
+        cls.b2 = Book.objects.create(
+            isbn='067232959', name='Sams Teach Yourself Django in 24 Hours',
+            pages=528, rating=3.0, price=Decimal('23.09'), contact=cls.a3, publisher=cls.p2,
+            pubdate=datetime.date(2008, 3, 3)
+        )
+
+    def test_aggregate_default_after_annotate(self):
+        """
+        Regression test for a crash when using aggregate() with a default
+        value after an annotate() call.
+        """
+        expected_result = Book.objects.aggregate(Sum('id'))
+        # This query will crash with an OperationalError on SQLite.
+        result = Book.objects.annotate(idx=F('id')).aggregate(Sum('id', default=0))
+        self.assertEqual(result, expected_result)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/aggregates\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 aggregation_regress.test_aggregate_after_annotate
cat coverage.cover
git checkout beb7ddbcee03270e833b2f74927ccfc8027aa693
git apply /root/pre_state.patch
