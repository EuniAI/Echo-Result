#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 00ea883ef56fb5e092cbe4a6f7ff2e7470886ac4 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 00ea883ef56fb5e092cbe4a6f7ff2e7470886ac4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/reverse_related.py b/django/db/models/fields/reverse_related.py
--- a/django/db/models/fields/reverse_related.py
+++ b/django/db/models/fields/reverse_related.py
@@ -310,7 +310,7 @@ def __init__(self, field, to, related_name=None, related_query_name=None,
     def identity(self):
         return super().identity + (
             self.through,
-            self.through_fields,
+            make_hashable(self.through_fields),
             self.db_constraint,
         )
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/check_framework/test_m2m_through_fields.py b/tests/check_framework/test_m2m_through_fields.py
new file mode 100644
index 0000000000..f2819cd1a0
--- /dev/null
+++ b/tests/check_framework/test_m2m_through_fields.py
@@ -0,0 +1,35 @@
+from django.core import checks
+from django.db import models
+from django.test import SimpleTestCase
+from django.test.utils import isolate_apps
+
+
+@isolate_apps('check_framework', attr_name='apps')
+class ManyToManyRelThroughFieldsCheckTests(SimpleTestCase):
+    def test_m2m_through_fields_list_hashable(self):
+        class Parent(models.Model):
+            name = models.CharField(max_length=256)
+
+        class Child(models.Model):
+            parent = models.ForeignKey(Parent, on_delete=models.CASCADE)
+            many_to_many_field = models.ManyToManyField(
+                to=Parent,
+                through='ManyToManyModel',
+                through_fields=['child', 'parent'],
+                related_name='something',
+            )
+
+        class ManyToManyModel(models.Model):
+            parent = models.ForeignKey(Parent, on_delete=models.CASCADE, related_name='+')
+            child = models.ForeignKey(Child, on_delete=models.CASCADE, related_name='+')
+            second_child = models.ForeignKey(
+                Child, on_delete=models.CASCADE, null=True, default=None,
+            )
+
+        class ProxyParent(Parent):
+            class Meta:
+                proxy = True
+
+        # Before the fix, this raises TypeError: unhashable type: 'list'.
+        # After the fix, it should return no errors.
+        self.assertEqual(ProxyParent.check(), [])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/reverse_related\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 check_framework.test_m2m_through_fields
cat coverage.cover
git checkout 00ea883ef56fb5e092cbe4a6f7ff2e7470886ac4
git apply /root/pre_state.patch
