#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 8dd5877f58f84f2b11126afbd0813e24545919ed >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 8dd5877f58f84f2b11126afbd0813e24545919ed
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/compiler.py b/django/db/models/sql/compiler.py
--- a/django/db/models/sql/compiler.py
+++ b/django/db/models/sql/compiler.py
@@ -722,6 +722,9 @@ def find_ordering_name(self, name, opts, alias=None, default_order='ASC',
 
             results = []
             for item in opts.ordering:
+                if isinstance(item, OrderBy):
+                    results.append((item, False))
+                    continue
                 results.extend(self.find_ordering_name(item, opts, alias,
                                                        order, already_seen))
             return results

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/ordering/test_f_expression_in_meta_ordering.py b/tests/ordering/test_f_expression_in_meta_ordering.py
new file mode 100644
index 0000000000..19e8230882
--- /dev/null
+++ b/tests/ordering/test_f_expression_in_meta_ordering.py
@@ -0,0 +1,54 @@
+from operator import attrgetter
+
+from django.db import models
+from django.db.models import F
+from django.test import TestCase
+
+
+# These models are defined at the module level to be correctly picked up by
+# Django's app-loading mechanism. The app_label ensures they are associated
+# with a specific, existing test app ('ordering').
+class OrderingParent(models.Model):
+    name = models.CharField(max_length=50)
+
+    class Meta:
+        app_label = 'ordering'
+        ordering = [F('name')]
+
+
+class OrderingChild(OrderingParent):
+    class Meta:
+        app_label = 'ordering'
+
+
+class OrderingHolder(models.Model):
+    child = models.ForeignKey(OrderingChild, on_delete=models.CASCADE)
+
+    class Meta:
+        app_label = 'ordering'
+
+
+class OrderByParentModelExpressionTests(TestCase):
+    # By setting available_apps, we ensure the test runner creates the tables
+    # for our test models before the test runs, solving the "no such table"
+    # and "doesn't declare an explicit app_label" errors.
+    available_apps = ['ordering']
+
+    def test_ordering_by_related_model_with_f_expression_in_meta(self):
+        c2 = OrderingChild.objects.create(name='c2')
+        c1 = OrderingChild.objects.create(name='c1')
+        h1 = OrderingHolder.objects.create(child=c1)
+        h2 = OrderingHolder.objects.create(child=c2)
+
+        # This is where the bug occurs. The query orders by 'child'. Django
+        # should look at the 'child' model (OrderingChild), find its
+        # Meta.ordering, which is inherited from OrderingParent. The ordering
+        # is `[F('name')]`.
+        #
+        # On the unpatched codebase, this fails with a TypeError because the
+        # F() object is passed to `get_order_dir` inside `find_ordering_name`,
+        # which expects a string.
+        self.assertQuerysetEqual(
+            OrderingHolder.objects.order_by('child'),
+            [h1, h2],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/compiler\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 ordering.test_f_expression_in_meta_ordering
cat coverage.cover
git checkout 8dd5877f58f84f2b11126afbd0813e24545919ed
git apply /root/pre_state.patch
