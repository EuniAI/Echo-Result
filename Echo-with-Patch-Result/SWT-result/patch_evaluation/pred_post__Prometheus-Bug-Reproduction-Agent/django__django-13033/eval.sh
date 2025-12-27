#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a59de6e89e8dc1f3e71c9a5a5bbceb373ea5247e >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a59de6e89e8dc1f3e71c9a5a5bbceb373ea5247e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/compiler.py b/django/db/models/sql/compiler.py
--- a/django/db/models/sql/compiler.py
+++ b/django/db/models/sql/compiler.py
@@ -727,7 +727,12 @@ def find_ordering_name(self, name, opts, alias=None, default_order='ASC',
         # If we get to this point and the field is a relation to another model,
         # append the default ordering for that model unless it is the pk
         # shortcut or the attribute name of the field that is specified.
-        if field.is_relation and opts.ordering and getattr(field, 'attname', None) != name and name != 'pk':
+        if (
+            field.is_relation and
+            opts.ordering and
+            getattr(field, 'attname', None) != pieces[-1] and
+            name != 'pk'
+        ):
             # Firstly, avoid infinite loops.
             already_seen = already_seen or set()
             join_tuple = tuple(getattr(self.query.alias_map[j], 'join_cols', None) for j in joins)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ordering_by_recursive_fk_attname.py b/tests/test_ordering_by_recursive_fk_attname.py
new file mode 100644
index 0000000000..c941d5f42b
--- /dev/null
+++ b/tests/test_ordering_by_recursive_fk_attname.py
@@ -0,0 +1,60 @@
+from django.db import models
+from django.test import TestCase
+
+
+class OneModel(models.Model):
+    """
+    A model with a self-referencing ForeignKey and a default ordering.
+    This matches the model described in the bug report.
+    """
+    root = models.ForeignKey('self', on_delete=models.CASCADE, null=True)
+    oneval = models.BigIntegerField(null=True)
+
+    class Meta:
+        ordering = ('-id',)
+
+
+class TwoModel(models.Model):
+    """
+    A model that references OneModel, as described in the bug report.
+    """
+    record = models.ForeignKey(OneModel, on_delete=models.CASCADE)
+    twoval = models.BigIntegerField(null=True)
+
+
+class OrderingByRecursiveFKAttnameTests(TestCase):
+    """
+    Tests the fix for ordering by a self-referencing FK's attname.
+    """
+    @classmethod
+    def setUpTestData(cls):
+        # Create two root objects. root1 will have a lower ID than root2.
+        cls.root1 = OneModel.objects.create()
+        cls.root2 = OneModel.objects.create()
+
+        # Create records that link to the roots in a way that ordering by
+        # root ID will be different from the default.
+        # record1 links to the root with the higher ID.
+        record1 = OneModel.objects.create(root=cls.root2)
+        # record2 links to the root with the lower ID.
+        record2 = OneModel.objects.create(root=cls.root1)
+
+        # Create the TwoModel objects to be queried.
+        cls.two_model_obj_1 = TwoModel.objects.create(record=record1)
+        cls.two_model_obj_2 = TwoModel.objects.create(record=record2)
+
+    def test_ordering_on_recursive_fk_attname(self):
+        """
+        Tests that ordering by a recursive FK's attname (e.g., 'field_id')
+        is not affected by the related model's default ordering.
+        """
+        # We expect to order by 'record__root_id' in ascending order.
+        # self.two_model_obj_2's related root has a lower ID than
+        # self.two_model_obj_1's. So, obj_2 should come first.
+        expected_order = [self.two_model_obj_2, self.two_model_obj_1]
+
+        # The bug causes this to order by 'record__root_id' descending because
+        # it incorrectly applies OneModel's Meta.ordering = ('-id',).
+        qs = TwoModel.objects.order_by('record__root_id')
+
+        self.assertSequenceEqual(qs, expected_order)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/compiler\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_ordering_by_recursive_fk_attname
cat coverage.cover
git checkout a59de6e89e8dc1f3e71c9a5a5bbceb373ea5247e
git apply /root/pre_state.patch
