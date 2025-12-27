#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f618e033acd37d59b536d6e6126e6c5be18037f6 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f618e033acd37d59b536d6e6126e6c5be18037f6
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/aggregation/test_distinct_aggregate.py b/tests/aggregation/test_distinct_aggregate.py
new file mode 100644
index 0000000000..92c7a196d1
--- /dev/null
+++ b/tests/aggregation/test_distinct_aggregate.py
@@ -0,0 +1,53 @@
+import datetime
+from decimal import Decimal
+
+from django.db.models import Avg, Sum
+from django.test import TestCase
+
+from .models import Author, Book, Publisher
+
+
+class AggregateDistinctTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        publisher = Publisher.objects.create(name='Apress', num_awards=3)
+        author = Author.objects.create(name='Adrian Holovaty', age=34)
+        Book.objects.create(
+            name='The Definitive Guide to Django',
+            pages=447,
+            rating=4.5,
+            price=Decimal('30.00'),
+            contact=author,
+            publisher=publisher,
+            pubdate=datetime.date(2007, 12, 6),
+        )
+        Book.objects.create(
+            name='Practical Django Projects',
+            pages=300,
+            rating=4.0,
+            price=Decimal('30.00'),
+            contact=author,
+            publisher=publisher,
+            pubdate=datetime.date(2008, 6, 23),
+        )
+        Book.objects.create(
+            name='Python Web Development with Django',
+            pages=350,
+            rating=4.0,
+            price=Decimal('29.69'),
+            contact=author,
+            publisher=publisher,
+            pubdate=datetime.date(2008, 11, 3),
+        )
+
+    def test_distinct_on_sum_avg(self):
+        """
+        The distinct parameter should be allowed on Sum and Avg aggregates.
+        """
+        result = Book.objects.aggregate(
+            price_sum=Sum('price', distinct=True),
+            price_avg=Avg('price', distinct=True),
+        )
+        # Distinct prices are 30.00 and 29.69.
+        self.assertEqual(result['price_sum'], Decimal('59.69'))
+        self.assertEqual(result['price_avg'], Decimal('29.845'))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/aggregates\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 aggregation.test_distinct_aggregate
cat coverage.cover
git checkout f618e033acd37d59b536d6e6126e6c5be18037f6
git apply /root/pre_state.patch
