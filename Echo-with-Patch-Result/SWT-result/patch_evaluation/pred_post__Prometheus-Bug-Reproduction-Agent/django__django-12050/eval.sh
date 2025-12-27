#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b93a0e34d9b9b99d41103782b7e7aeabf47517e3 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b93a0e34d9b9b99d41103782b7e7aeabf47517e3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/query.py b/django/db/models/sql/query.py
--- a/django/db/models/sql/query.py
+++ b/django/db/models/sql/query.py
@@ -1059,21 +1059,10 @@ def resolve_lookup_value(self, value, can_reuse, allow_joins, simple_col):
         elif isinstance(value, (list, tuple)):
             # The items of the iterable may be expressions and therefore need
             # to be resolved independently.
-            resolved_values = []
-            for sub_value in value:
-                if hasattr(sub_value, 'resolve_expression'):
-                    if isinstance(sub_value, F):
-                        resolved_values.append(sub_value.resolve_expression(
-                            self, reuse=can_reuse, allow_joins=allow_joins,
-                            simple_col=simple_col,
-                        ))
-                    else:
-                        resolved_values.append(sub_value.resolve_expression(
-                            self, reuse=can_reuse, allow_joins=allow_joins,
-                        ))
-                else:
-                    resolved_values.append(sub_value)
-            value = tuple(resolved_values)
+            return type(value)(
+                self.resolve_lookup_value(sub_value, can_reuse, allow_joins, simple_col)
+                for sub_value in value
+            )
         return value
 
     def solve_lookup_type(self, lookup):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lookup/tests/test_resolve_lookup_value.py b/lookup/tests/test_resolve_lookup_value.py
new file mode 100644
index 0000000000..bd98f10233
--- /dev/null
+++ b/lookup/tests/test_resolve_lookup_value.py
@@ -0,0 +1,57 @@
+from django.db import models
+from django.test import TestCase
+
+
+class ReprField(models.CharField):
+    """
+    A custom CharField that stores the repr() of a value. This is used to
+    create a field that is sensitive to the difference between a list and a
+    tuple, which is the core of the bug.
+    """
+    def __init__(self, *args, **kwargs):
+        kwargs.setdefault('max_length', 255)
+        super().__init__(*args, **kwargs)
+
+    def from_db_value(self, value, expression, connection):
+        # This method is not strictly necessary for the test to fail, but it's
+        # good practice for a custom field to be able to convert data back.
+        # eval() is safe here because we control the data being stored.
+        if value is None:
+            return value
+        return eval(value)
+
+    def get_prep_value(self, value):
+        # This is called when preparing a value for a query. Before the fix,
+        # a list `[1, 2]` would be coerced to a tuple `(1, 2)`, and this
+        # method would receive the tuple. `repr([1, 2])` is different from
+        # `repr((1, 2))`, causing the database lookup to fail.
+        return repr(value)
+
+
+class ReprModel(models.Model):
+    value = ReprField()
+
+    class Meta:
+        # The model must be associated with an existing test application
+        # ('lookup' in this case) for the test runner to create its table.
+        app_label = 'lookup'
+
+
+class ResolveLookupValueTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.repr_list = [1, 2, '3']
+        # The value stored in the database will be the string "[1, 2, '3']".
+        cls.obj = ReprModel.objects.create(value=cls.repr_list)
+
+    def test_list_is_not_coerced_to_tuple(self):
+        """
+        Query.resolve_lookup_value() shouldn't coerce a list to a tuple.
+        """
+        # Before the fix, this get() call fails with DoesNotExist. The query
+        # value `self.repr_list` (a list) is incorrectly converted to a
+        # tuple. The repr() of the tuple does not match the repr() of the list
+        # stored in the database, so no object is found.
+        # With the fix, the list type is preserved, the repr() matches, and
+        # the object is found correctly.
+        self.assertEqual(ReprModel.objects.get(value=self.repr_list), self.obj)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 lookup.tests.test_resolve_lookup_value
cat coverage.cover
git checkout b93a0e34d9b9b99d41103782b7e7aeabf47517e3
git apply /root/pre_state.patch
