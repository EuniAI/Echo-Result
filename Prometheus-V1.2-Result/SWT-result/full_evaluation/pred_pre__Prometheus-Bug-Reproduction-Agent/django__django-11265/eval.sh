#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 21aa2a5e785eef1f47beb1c3760fdd7d8915ae09 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 21aa2a5e785eef1f47beb1c3760fdd7d8915ae09
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/filtered_relation/test_exclude_on_annotated_filtered_relation.py b/tests/filtered_relation/test_exclude_on_annotated_filtered_relation.py
new file mode 100644
index 0000000000..1c350411e7
--- /dev/null
+++ b/tests/filtered_relation/test_exclude_on_annotated_filtered_relation.py
@@ -0,0 +1,51 @@
+from django.db.models import FilteredRelation, Q
+from django.test import TestCase
+
+from .models import Author, Book, Editor
+
+
+class FilteredRelationTests(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.author1 = Author.objects.create(name='Alice')
+        cls.author2 = Author.objects.create(name='Jane')
+        cls.editor_a = Editor.objects.create(name='a')
+        cls.editor_b = Editor.objects.create(name='b')
+        cls.book1 = Book.objects.create(
+            title='Poem by Alice',
+            editor=cls.editor_a,
+            author=cls.author1,
+        )
+        cls.book1.generic_author.set([cls.author2])
+        cls.book2 = Book.objects.create(
+            title='The book by Jane A',
+            editor=cls.editor_b,
+            author=cls.author2,
+        )
+        cls.book3 = Book.objects.create(
+            title='The book by Jane B',
+            editor=cls.editor_b,
+            author=cls.author2,
+        )
+        cls.book4 = Book.objects.create(
+            title='The book by Alice',
+            editor=cls.editor_a,
+            author=cls.author1,
+        )
+        cls.author1.favorite_books.add(cls.book2)
+        cls.author1.favorite_books.add(cls.book3)
+
+    def test_exclude_on_annotated_filtered_relation(self):
+        """
+        exclude() on a queryset with an annotated FilteredRelation shouldn't
+        raise a FieldError.
+        """
+        self.assertSequenceEqual(
+            Author.objects.annotate(
+                book_alice=FilteredRelation(
+                    'book', condition=Q(book__title__iexact='poem by alice')
+                ),
+            ).exclude(book_alice__isnull=False),
+            [self.author2]
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 filtered_relation.test_exclude_on_annotated_filtered_relation
cat coverage.cover
git checkout 21aa2a5e785eef1f47beb1c3760fdd7d8915ae09
git apply /root/pre_state.patch
