#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 06fd4df41afb5aa1d681b853c3c08d8c688ca3a5 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 06fd4df41afb5aa1d681b853c3c08d8c688ca3a5
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/lookups.py b/django/db/models/lookups.py
--- a/django/db/models/lookups.py
+++ b/django/db/models/lookups.py
@@ -406,6 +406,15 @@ def process_rhs(self, compiler, connection):
                 self.rhs.add_fields(['pk'])
             return super().process_rhs(compiler, connection)
 
+    def get_group_by_cols(self, alias=None):
+        cols = self.lhs.get_group_by_cols()
+        if hasattr(self.rhs, 'get_group_by_cols'):
+            if not getattr(self.rhs, 'has_select_fields', True):
+                self.rhs.clear_select_clause()
+                self.rhs.add_fields(['pk'])
+            cols.extend(self.rhs.get_group_by_cols())
+        return cols
+
     def get_rhs_op(self, connection, rhs):
         return 'IN %s' % rhs
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/queries/tests/test_or_in_operator.py b/queries/tests/test_or_in_operator.py
new file mode 100644
index 0000000000..c7570255b7
--- /dev/null
+++ b/queries/tests/test_or_in_operator.py
@@ -0,0 +1,61 @@
+import datetime
+
+from django.db.models import Count, Q
+from django.test import TestCase
+
+from .models import Author, Cover, ExtraInfo, Item, Note, Tag
+
+
+class OrInTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.note1 = Note.objects.create(note='note1')
+        cls.note2 = Note.objects.create(note='note2')
+
+        cls.extra1 = ExtraInfo.objects.create(info='extra1', note=cls.note1)
+        cls.extra2 = ExtraInfo.objects.create(info='extra2', note=cls.note2)
+
+        cls.author1 = Author.objects.create(name='author1', num=1, extra=cls.extra1)
+        cls.author2 = Author.objects.create(name='author2', num=2, extra=cls.extra2)
+
+        cls.tag1 = Tag.objects.create(name='tag1')
+        cls.tag2 = Tag.objects.create(name='tag2')
+
+        # Item with a tag.
+        cls.item1 = Item.objects.create(
+            name='item1',
+            created=datetime.datetime.now(),
+            creator=cls.author1,
+            note=cls.note1,
+        )
+        cls.item1.tags.add(cls.tag1)
+
+        # Item with no tags.
+        cls.item2 = Item.objects.create(
+            name='item2',
+            created=datetime.datetime.now(),
+            creator=cls.author2,
+            note=cls.note2,
+        )
+
+        cls.cover1 = Cover.objects.create(title='cover1', item=cls.item1)
+        cls.cover2 = Cover.objects.create(title='cover2', item=cls.item2)
+
+    def test_q_in_or_count(self):
+        """
+        A query combining a nested __in lookup with a count annotation
+        on the same relation in a Q object OR should not fail.
+        """
+        covers = Cover.objects.annotate(item__tags__count=Count('item__tags'))
+        tags = Tag.objects.filter(name='tag1')
+
+        # This query fails on unpatched Django with a ProgrammingError because
+        # the subquery for `item__tags__in` selects all columns from the
+        # Tag model, which is invalid in an IN clause.
+        qs = covers.filter(
+            Q(item__tags__in=tags) | Q(item__tags__count=0)
+        ).distinct()
+
+        # The query should return cover1 (item has tag1) and cover2
+        # (item has 0 tags).
+        self.assertCountEqual(qs, [self.cover1, self.cover2])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/lookups\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.tests.test_or_in_operator
cat coverage.cover
git checkout 06fd4df41afb5aa1d681b853c3c08d8c688ca3a5
git apply /root/pre_state.patch
