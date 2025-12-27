#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 71ae1ab0123582cc5bfe0f7d5f4cc19a9412f396 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 71ae1ab0123582cc5bfe0f7d5f4cc19a9412f396
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/query.py b/django/db/models/query.py
--- a/django/db/models/query.py
+++ b/django/db/models/query.py
@@ -1224,7 +1224,12 @@ def ordered(self):
             return True
         if self.query.extra_order_by or self.query.order_by:
             return True
-        elif self.query.default_ordering and self.query.get_meta().ordering:
+        elif (
+            self.query.default_ordering and
+            self.query.get_meta().ordering and
+            # A default ordering doesn't affect GROUP BY queries.
+            not self.query.group_by
+        ):
             return True
         else:
             return False

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_aggregation.py b/tests/test_aggregation.py
new file mode 100644
index 0000000000..78f2d8c4c7
--- /dev/null
+++ b/tests/test_aggregation.py
@@ -0,0 +1,105 @@
+import datetime
+from decimal import Decimal
+
+from django.db.models import Count
+from django.test import TestCase
+
+from .models import Author, Book, HardbackBook, Publisher, Store
+
+
+class AggregationTests(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.a1 = Author.objects.create(name='Adrian Holovaty', age=34)
+        cls.a2 = Author.objects.create(name='Jacob Kaplan-Moss', age=35)
+        cls.a3 = Author.objects.create(name='Brad Dayley', age=45)
+        cls.a4 = Author.objects.create(name='James Bennett', age=29)
+        cls.a5 = Author.objects.create(name='Jeffrey Forcier', age=37)
+        cls.a6 = Author.objects.create(name='Paul Bissex', age=29)
+        cls_a7 = Author.objects.create(name='Wesley J. Chun', age=25)
+        cls.a8 = Author.objects.create(name='Peter Norvig', age=57)
+        cls.a9 = Author.objects.create(name='Stuart Russell', age=46)
+        cls.a1.friends.add(cls.a2, cls.a4)
+        cls.a2.friends.add(cls.a1, cls_a7)
+        cls.a4.friends.add(cls.a1)
+        cls.a5.friends.add(cls.a6, cls_a7)
+        cls.a6.friends.add(cls.a5, cls_a7)
+        cls_a7.friends.add(cls.a2, cls.a5, cls.a6)
+        cls.a8.friends.add(cls.a9)
+        cls.a9.friends.add(cls.a8)
+
+        cls.p1 = Publisher.objects.create(name='Apress', num_awards=3)
+        cls.p2 = Publisher.objects.create(name='Sams', num_awards=1)
+        cls.p3 = Publisher.objects.create(name='Prentice Hall', num_awards=7)
+        cls.p4 = Publisher.objects.create(name='Morgan Kaufmann', num_awards=9)
+        cls.p5 = Publisher.objects.create(name="Jonno's House of Books", num_awards=0)
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
+        cls.b3 = Book.objects.create(
+            isbn='159059996', name='Practical Django Projects',
+            pages=300, rating=4.0, price=Decimal('29.69'), contact=cls.a4, publisher=cls.p1,
+            pubdate=datetime.date(2008, 6, 23)
+        )
+        cls.b4 = Book.objects.create(
+            isbn='013235613', name='Python Web Development with Django',
+            pages=350, rating=4.0, price=Decimal('29.69'), contact=cls.a5, publisher=cls.p3,
+            pubdate=datetime.date(2008, 11, 3)
+        )
+        cls.b5 = HardbackBook.objects.create(
+            isbn='013790395', name='Artificial Intelligence: A Modern Approach',
+            pages=1132, rating=4.0, price=Decimal('82.80'), contact=cls.a8, publisher=cls.p3,
+            pubdate=datetime.date(1995, 1, 15), weight=4.5)
+        cls.b6 = HardbackBook.objects.create(
+            isbn='155860191',
+            name='Paradigms of Artificial Intelligence Programming: Case Studies in Common Lisp',
+            pages=946, rating=5.0, price=Decimal('75.00'), contact=cls.a8, publisher=cls.p4,
+            pubdate=datetime.date(1991, 10, 15), weight=3.7)
+        cls.b1.authors.add(cls.a1, cls.a2)
+        cls.b2.authors.add(cls.a3)
+        cls.b3.authors.add(cls.a4)
+        cls.b4.authors.add(cls.a5, cls.a6, cls_a7)
+        cls.b5.authors.add(cls.a8, cls.a9)
+        cls.b6.authors.add(cls.a8)
+
+        s1 = Store.objects.create(
+            name='Amazon.com',
+            original_opening=datetime.datetime(1994, 4, 23, 9, 17, 42),
+            friday_night_closing=datetime.time(23, 59, 59)
+        )
+        s2 = Store.objects.create(
+            name='Books.com',
+            original_opening=datetime.datetime(2001, 3, 15, 11, 23, 37),
+            friday_night_closing=datetime.time(23, 59, 59)
+        )
+        s3 = Store.objects.create(
+            name="Mamma and Pappa's Books",
+            original_opening=datetime.datetime(1945, 4, 25, 16, 24, 14),
+            friday_night_closing=datetime.time(21, 30)
+        )
+        s1.books.add(cls.b1, cls.b2, cls.b3, cls.b4, cls.b5, cls.b6)
+        s2.books.add(cls.b1, cls.b3, cls.b5, cls.b6)
+        s3.books.add(cls.b3, cls.b4, cls.b6)
+
+    def test_ordered_property_on_grouped_queryset(self):
+        """
+        The `ordered` property should be False for a grouped queryset that
+        doesn't have an explicit ordering.
+        """
+        # A queryset on a model with Meta.ordering is ordered.
+        qs = Book.objects.all()
+        self.assertTrue(qs.ordered)
+
+        # Annotating with an aggregate should group the query and drop the
+        # default ordering.
+        qs = qs.annotate(Count('pk'))
+        self.assertFalse(qs.ordered)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_aggregation
cat coverage.cover
git checkout 71ae1ab0123582cc5bfe0f7d5f4cc19a9412f396
git apply /root/pre_state.patch
