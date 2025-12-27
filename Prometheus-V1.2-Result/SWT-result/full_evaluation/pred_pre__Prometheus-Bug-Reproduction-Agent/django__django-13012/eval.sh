#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 22a59c01c00cf9fbefaee0e8e67fab82bbaf1fd2 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 22a59c01c00cf9fbefaee0e8e67fab82bbaf1fd2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/aggregation_regress/test_grouping.py b/tests/aggregation_regress/test_grouping.py
new file mode 100644
index 0000000000..7088e303ef
--- /dev/null
+++ b/tests/aggregation_regress/test_grouping.py
@@ -0,0 +1,68 @@
+import datetime
+from decimal import Decimal
+
+from django.db.models import (
+    ExpressionWrapper, IntegerField, Sum, Value
+)
+from django.test import TestCase
+
+from .models import Author, Book, Publisher
+
+
+class AggregateTestCase(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.a1 = Author.objects.create(name='Adrian Holovaty', age=34)
+        cls.a3 = Author.objects.create(name='Brad Dayley', age=45)
+        cls.a4 = Author.objects.create(name='James Bennett', age=29)
+        cls.a5 = Author.objects.create(name='Jeffrey Forcier', age=37)
+        cls.a8 = Author.objects.create(name='Peter Norvig', age=57)
+
+        cls.p1 = Publisher.objects.create(name='Apress', num_awards=3)
+        cls.p2 = Publisher.objects.create(name='Sams', num_awards=1)
+        cls.p3 = Publisher.objects.create(name='Prentice Hall', num_awards=7)
+        cls.p4 = Publisher.objects.create(name='Morgan Kaufmann', num_awards=9)
+
+        Book.objects.create(
+            pages=447, rating=4.5, contact=cls.a1, publisher=cls.p1,
+            name='The Definitive Guide to Django: Web Development Done Right',
+        )
+        Book.objects.create(
+            pages=528, rating=3.0, contact=cls.a3, publisher=cls.p2,
+            name='Sams Teach Yourself Django in 24 Hours',
+        )
+        Book.objects.create(
+            pages=300, rating=4.0, contact=cls.a4, publisher=cls.p1,
+            name='Practical Django Projects',
+        )
+        Book.objects.create(
+            pages=350, rating=4.0, contact=cls.a5, publisher=cls.p3,
+            name='Python Web Development with Django',
+        )
+        Book.objects.create(
+            pages=1132, rating=4.0, contact=cls.a8, publisher=cls.p3,
+            name='Artificial Intelligence: A Modern Approach',
+        )
+        Book.objects.create(
+            pages=946, rating=5.0, contact=cls.a8, publisher=cls.p4,
+            name='Paradigms of Artificial Intelligence Programming: Case Studies in Common Lisp',
+        )
+
+    def test_constant_expression_wrapper_not_in_group_by(self):
+        """
+        A constant wrapped in ExpressionWrapper shouldn't be added to the
+        GROUP BY clause.
+        """
+        qs = Book.objects.annotate(
+            expr=ExpressionWrapper(Value(3), output_field=IntegerField())
+        ).values('expr', 'rating').annotate(sum_pages=Sum('pages'))
+
+        compiler = qs.query.get_compiler(using='default')
+        # pre_sql_setup() returns select, where, group_by, having, order_by,
+        # and select_mask.
+        _, _, group_by, _, _, _ = compiler.pre_sql_setup()
+
+        # The GROUP BY clause should only contain 'rating', not the constant
+        # 'expr'. With the bug, len(group_by) is 2. After the fix, it will be 1.
+        self.assertEqual(len(group_by), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 aggregation_regress.test_grouping
cat coverage.cover
git checkout 22a59c01c00cf9fbefaee0e8e67fab82bbaf1fd2
git apply /root/pre_state.patch
