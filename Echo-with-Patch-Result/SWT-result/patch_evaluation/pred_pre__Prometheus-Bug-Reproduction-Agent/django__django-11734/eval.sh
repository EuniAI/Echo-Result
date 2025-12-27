#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 999891bd80b3d02dd916731a7a239e1036174885 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 999891bd80b3d02dd916731a7a239e1036174885
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/queries/test_exists_exclude_combinator.py b/tests/queries/test_exists_exclude_combinator.py
new file mode 100644
index 0000000000..058b20f196
--- /dev/null
+++ b/tests/queries/test_exists_exclude_combinator.py
@@ -0,0 +1,56 @@
+import datetime
+
+from django.db.models import Exists, OuterRef, Q
+from django.test import TestCase
+
+from .models import Author, ExtraInfo, Item, NamedCategory, Note, Number, Tag
+
+
+class QSCombinatorsTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.category = NamedCategory.objects.create(name='cat')
+        cls.tag = Tag.objects.create(name='tag1', category=cls.category)
+        # The bug report uses OuterRef('pk') on the Number model, but its pk
+        # is an auto-field, so we can't easily match it to a category's pk.
+        # We'll use the 'num' field and OuterRef('num') instead to make the
+        # test deterministic.
+        cls.matching_number = Number.objects.create(num=cls.category.pk)
+        cls.other_number = Number.objects.create(num=cls.category.pk + 100)
+
+        # Item creation dependencies.
+        note = Note.objects.create(note='n', misc='m')
+        extrainfo = ExtraInfo.objects.create(info='e', note=note)
+        author = Author.objects.create(name='a', num=1, extra=extrainfo)
+
+        item_with_tag = Item.objects.create(
+            name='item1',
+            created=datetime.datetime.now(),
+            creator=author,
+            note=note,
+        )
+        item_with_tag.tags.add(cls.tag)
+        Item.objects.create(
+            name='item2',
+            created=datetime.datetime.now(),
+            creator=author,
+            note=note,
+        )
+
+    def test_exists_exclude(self):
+        qs = Number.objects.annotate(
+            foo=Exists(Item.objects.exclude(tags__category_id=OuterRef('num')))
+        ).filter(foo=True)
+        # This query will crash with a ValueError before the bug is fixed.
+        # After it's fixed, the query should return all Number objects for
+        # which there is at least one Item that doesn't have a tag with a
+        # category ID matching the number's 'num' value. In this test's
+        # setup, this is true for all numbers.
+        self.assertCountEqual(qs, [self.matching_number, self.other_number])
+
+    def test_exists_filter_negated_q(self):
+        qs = Number.objects.annotate(
+            foo=Exists(Item.objects.filter(~Q(tags__category_id=OuterRef('num'))))
+        ).filter(foo=True)
+        # This query will crash with a ValueError before the bug is fixed.
+        self.assertCountEqual(qs, [self.other_number])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py|django/db/models/sql/query\.py|django/db/models/fields/related_lookups\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_exists_exclude_combinator
cat coverage.cover
git checkout 999891bd80b3d02dd916731a7a239e1036174885
git apply /root/pre_state.patch
