#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ba726067604ce5a8ca3919edf653496722b433ab >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ba726067604ce5a8ca3919edf653496722b433ab
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/generic_relations/test_prefetch.py b/tests/generic_relations/test_prefetch.py
new file mode 100644
index 0000000000..12b69b1011
--- /dev/null
+++ b/tests/generic_relations/test_prefetch.py
@@ -0,0 +1,53 @@
+from django.test import TestCase
+
+from .models import Book, Comment, Pet, Reader, TaggedItem
+
+
+class GenericRelationTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        book1 = Book.objects.create(title="Winnie the Pooh")
+        book2 = Book.objects.create(title="Do you like green eggs and spam?")
+        book3 = Book.objects.create(title="Three Men In A Boat")
+
+        reader1 = Reader.objects.create(name="me")
+        reader2 = Reader.objects.create(name="you")
+        reader3 = Reader.objects.create(name="someone")
+
+        book1.read_by.add(reader1, reader2)
+        book2.read_by.add(reader2)
+        book3.read_by.add(reader3)
+
+        cls.book1, cls.book2, cls.book3 = book1, book2, book3
+        cls.reader1, cls.reader2, cls.reader3 = reader1, reader2, reader3
+
+    def test_prefetch_GFK(self):
+        TaggedItem.objects.create(tag="awesome", content_object=self.book1)
+        TaggedItem.objects.create(tag="great", content_object=self.reader1)
+        TaggedItem.objects.create(tag="outstanding", content_object=self.book2)
+        TaggedItem.objects.create(tag="amazing", content_object=self.reader3)
+
+        # 1 for TaggedItem table, 1 for Book table, 1 for Reader table
+        with self.assertNumQueries(3):
+            qs = TaggedItem.objects.prefetch_related("content_object")
+            list(qs)
+
+    def test_prefetch_GFK_nonint_pk(self):
+        Comment.objects.create(comment="awesome", content_object=self.book1)
+
+        # 1 for Comment table, 1 for Book table
+        with self.assertNumQueries(2):
+            qs = Comment.objects.prefetch_related("content_object")
+            [c.content_object for c in qs]
+
+    def test_prefetch_GFK_uuid_pk(self):
+        """
+        A GFK prefetch should work with a UUID PK.
+        """
+        pet = Pet.objects.create(name="Socks")
+        comment = Comment.objects.create(comment="cute", content_object=pet)
+        with self.assertNumQueries(2):
+            qs = Comment.objects.prefetch_related("content_object")
+            prefetched_comment = list(qs)[0]
+        with self.assertNumQueries(0):
+            self.assertEqual(prefetched_comment.content_object, pet)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 generic_relations.test_prefetch
cat coverage.cover
git checkout ba726067604ce5a8ca3919edf653496722b433ab
git apply /root/pre_state.patch
