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
diff --git a/tests/model_inheritance_regress/test_ordering_by_child_relation.py b/tests/model_inheritance_regress/test_ordering_by_child_relation.py
new file mode 100644
index 0000000000..46b3883f30
--- /dev/null
+++ b/tests/model_inheritance_regress/test_ordering_by_child_relation.py
@@ -0,0 +1,46 @@
+import unittest
+
+from django.db import models
+from django.db.models import F
+from django.test import TestCase
+from django.test.utils import isolate_apps
+
+
+@isolate_apps('model_inheritance_regress')
+class ParentOrderByChildRelationTests(TestCase):
+    """
+    Tests ordering a parent model by its child relation, where the child
+    has an expression in `Meta.ordering`.
+    """
+
+    class OrderableParent(models.Model):
+        name = models.CharField(max_length=50)
+
+        class Meta:
+            app_label = 'model_inheritance_regress'
+
+    class OrderableChild(OrderableParent):
+        class Meta:
+            app_label = 'model_inheritance_regress'
+            ordering = (F('name').desc(),)
+
+    def test_order_by_child_relation_crashes(self):
+        """
+        Ordering a parent queryset by the reverse relation to a child should
+        not crash when the child's `Meta.ordering` contains an expression.
+        """
+        self.OrderableChild.objects.create(name='c1')
+        self.OrderableParent.objects.create(name='p1')
+
+        # Query the parent model, and order by the reverse one-to-one
+        # relation to the child. The default name for this relation is the
+        # lowercased child model name: 'orderablechild'.
+        # This tells Django to use the default ordering of the child model.
+        qs = self.OrderableParent.objects.order_by('orderablechild')
+
+        # The child's `Meta.ordering` contains an F() expression, which
+        # resolves to an OrderBy object. When Django tries to apply this
+        # ordering to the parent query, it can pass the raw OrderBy object
+        # to internal functions that expect a string, causing a crash.
+        # Evaluating the queryset will trigger the bug.
+        list(qs)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/compiler\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_inheritance_regress.test_ordering_by_child_relation
cat coverage.cover
git checkout 8dd5877f58f84f2b11126afbd0813e24545919ed
git apply /root/pre_state.patch
