#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 838e432e3e5519c5383d12018e6c78f8ec7833c1 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 838e432e3e5519c5383d12018e6c78f8ec7833c1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/aggregation_regress/test_distinct_conditional_count.py b/tests/aggregation_regress/test_distinct_conditional_count.py
new file mode 100644
index 0000000000..358df1fbb2
--- /dev/null
+++ b/tests/aggregation_regress/test_distinct_conditional_count.py
@@ -0,0 +1,98 @@
+import datetime
+from decimal import Decimal
+
+from django.db.models import Case, Count, When
+from django.test import TestCase
+
+from .models import Author, Book, HardbackBook, Publisher
+
+
+class AggregationTests(TestCase):
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
+        cls.a1.friends.add(cls.a2, cls.a4)
+        cls.a2.friends.add(cls.a1, cls.a7)
+        cls.a4.friends.add(cls.a1)
+        cls.a5.friends.add(cls.a6, cls.a7)
+        cls.a6.friends.add(cls.a5, cls.a7)
+        cls.a7.friends.add(cls.a2, cls.a5, cls.a6)
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
+            isbn='155860191', name='Paradigms of Artificial Intelligence Programming: Case Studies in Common Lisp',
+            pages=946, rating=5.0, price=Decimal('75.00'), contact=cls.a8, publisher=cls.p4,
+            pubdate=datetime.date(1991, 10, 15), weight=3.7)
+        cls.b1.authors.add(cls.a1, cls.a2)
+        cls.b2.authors.add(cls.a3)
+        cls.b3.authors.add(cls.a4)
+        cls.b4.authors.add(cls.a5, cls.a6, cls.a7)
+        cls.b5.authors.add(cls.a8, cls.a9)
+        cls.b6.authors.add(cls.a8)
+
+    def test_distinct_conditional_count_annotation(self):
+        """
+        A Count annotation with a conditional expression and distinct=True
+        should not generate invalid SQL.
+        """
+        # This query triggers the bug, which raises a DatabaseError because
+        # of the invalid SQL: COUNT(DISTINCTCASE WHEN...). The test will fail
+        # due to the unhandled exception. When the bug is fixed, the query
+        # will succeed and the assertion will pass.
+        qs = Publisher.objects.annotate(
+            distinct_book_count=Count(
+                Case(When(book__rating__gt=4.0, then='book__pk')),
+                distinct=True,
+            ),
+        ).order_by('name')
+
+        # This executes the query, triggering the database error.
+        results = {p.name: p.distinct_book_count for p in qs}
+
+        # These assertions will run only after the bug is fixed.
+        self.assertEqual(results, {
+            'Apress': 1,
+            "Jonno's House of Books": 0,
+            'Morgan Kaufmann': 1,
+            'Prentice Hall': 0,
+            'Sams': 0,
+        })

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/aggregates\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 aggregation_regress.test_distinct_conditional_count
cat coverage.cover
git checkout 838e432e3e5519c5383d12018e6c78f8ec7833c1
git apply /root/pre_state.patch
