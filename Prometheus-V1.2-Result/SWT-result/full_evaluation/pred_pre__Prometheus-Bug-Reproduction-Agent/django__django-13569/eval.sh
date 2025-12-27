#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 257f8495d6c93e30ab0f52af4c488d7344bcf112 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 257f8495d6c93e30ab0f52af4c488d7344bcf112
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/ordering/test_random_ordering_aggregation.py b/tests/ordering/test_random_ordering_aggregation.py
new file mode 100644
index 0000000000..4007ee76b9
--- /dev/null
+++ b/tests/ordering/test_random_ordering_aggregation.py
@@ -0,0 +1,33 @@
+import datetime
+
+from django.db.models import Count
+from django.test import TestCase
+
+from .models import Article, Author
+
+
+class OrderingTests(TestCase):
+    def test_random_ordering_doesnt_break_aggregation(self):
+        """
+        A random order_by() shouldn't break an aggregate's GROUP BY clause.
+        """
+        author = Author.objects.create(name='Test Author')
+        Article.objects.create(
+            headline='Article A',
+            pub_date=datetime.datetime(2020, 1, 1),
+            author=author,
+        )
+        Article.objects.create(
+            headline='Article B',
+            pub_date=datetime.datetime(2020, 1, 2),
+            author=author,
+        )
+
+        qs = Author.objects.filter(pk=author.pk).annotate(
+            article_count=Count('article')
+        ).order_by('?').values('pk', 'article_count')
+
+        # The bug causes random ordering to be added to GROUP BY, resulting in
+        # one result per related article. The correct result is a single row
+        # with the count of all articles.
+        self.assertCountEqual(qs, [{'pk': author.pk, 'article_count': 2}])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/functions/math\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 ordering.test_random_ordering_aggregation
cat coverage.cover
git checkout 257f8495d6c93e30ab0f52af4c488d7344bcf112
git apply /root/pre_state.patch
