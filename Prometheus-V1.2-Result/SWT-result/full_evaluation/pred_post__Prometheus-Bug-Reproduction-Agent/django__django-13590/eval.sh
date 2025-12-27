#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 755dbf39fcdc491fe9b588358303e259c7750be4 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 755dbf39fcdc491fe9b588358303e259c7750be4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/query.py b/django/db/models/sql/query.py
--- a/django/db/models/sql/query.py
+++ b/django/db/models/sql/query.py
@@ -1077,10 +1077,14 @@ def resolve_lookup_value(self, value, can_reuse, allow_joins):
         elif isinstance(value, (list, tuple)):
             # The items of the iterable may be expressions and therefore need
             # to be resolved independently.
-            return type(value)(
+            values = (
                 self.resolve_lookup_value(sub_value, can_reuse, allow_joins)
                 for sub_value in value
             )
+            type_ = type(value)
+            if hasattr(type_, '_make'):  # namedtuple
+                return type_(*values)
+            return type_(values)
         return value
 
     def solve_lookup_type(self, lookup):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/lookup/test_range_namedtuple.py b/tests/lookup/test_range_namedtuple.py
new file mode 100644
index 0000000000..5b90d41a4c
--- /dev/null
+++ b/tests/lookup/test_range_namedtuple.py
@@ -0,0 +1,53 @@
+import collections.abc
+from collections import namedtuple
+from datetime import datetime
+from math import ceil
+from operator import attrgetter
+
+from django.core.exceptions import FieldError
+from django.db import connection, models
+from django.db.models import Exists, Max, OuterRef
+from django.db.models.functions import Substr
+from django.test import TestCase, skipUnlessDBFeature
+from django.test.utils import isolate_apps
+from django.utils.deprecation import RemovedInDjango40Warning
+
+from .models import (
+    Article, Author, Freebie, Game, IsNullWithNoneAsRHS, Player, Season, Tag,
+)
+
+
+class RangeNamedTupleTest(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.au1 = Author.objects.create(name='Author 1', alias='a1')
+        cls.au2 = Author.objects.create(name='Author 2', alias='a2')
+        cls.a1 = Article.objects.create(headline='Article 1', pub_date=datetime(2005, 7, 26), author=cls.au1, slug='a1')
+        cls.a2 = Article.objects.create(headline='Article 2', pub_date=datetime(2005, 7, 27), author=cls.au1, slug='a2')
+        cls.a3 = Article.objects.create(headline='Article 3', pub_date=datetime(2005, 7, 27), author=cls.au1, slug='a3')
+        cls.a4 = Article.objects.create(headline='Article 4', pub_date=datetime(2005, 7, 28), author=cls.au1, slug='a4')
+        cls.a5 = Article.objects.create(headline='Article 5', pub_date=datetime(2005, 8, 1, 9, 0), author=cls.au2, slug='a5')
+        cls.a6 = Article.objects.create(headline='Article 6', pub_date=datetime(2005, 8, 1, 8, 0), author=cls.au2, slug='a6')
+        cls.a7 = Article.objects.create(headline='Article 7', pub_date=datetime(2005, 7, 27), author=cls.au2, slug='a7')
+        cls.t1 = Tag.objects.create(name='Tag 1')
+        cls.t1.articles.add(cls.a1, cls.a2, cls.a3)
+        cls.t2 = Tag.objects.create(name='Tag 2')
+        cls.t2.articles.add(cls.a3, cls.a4, cls.a5)
+        cls.t3 = Tag.objects.create(name='Tag 3')
+        cls.t3.articles.add(cls.a5, cls.a6, cls.a7)
+
+
+    def test_range_namedtuple(self):
+        DateRange = namedtuple('DateRange', ['near', 'far'])
+        start_date = datetime(2005, 7, 27)
+        end_date = datetime(2005, 7, 28)
+        date_range = DateRange(near=start_date, far=end_date)
+        # This should not raise a TypeError.
+        qs = Article.objects.filter(pub_date__range=date_range)
+        self.assertQuerysetEqual(
+            qs,
+            [self.a2.pk, self.a3.pk, self.a4.pk, self.a7.pk],
+            transform=attrgetter('pk'),
+            ordered=False,
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 lookup.test_range_namedtuple
cat coverage.cover
git checkout 755dbf39fcdc491fe9b588358303e259c7750be4
git apply /root/pre_state.patch
