#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 755dbf39fcdc491fe9b588358303e259c7750be4 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 755dbf39fcdc491fe9b588358303e259c7750be4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/query.py b/django/db/models/sql/query.py
--- a/django/db/models/sql/query.py
+++ b/django/db/models/sql/query.py
@@ -1077,10 +1077,14 @@ def resolve_lookup_value(self, value, can_reuse, allow_joins):
         elif isinstance(value, (list, tuple)):
             # The items of the iterable may be expressions and therefore need
             # to be resolved independently.
-            return type(value)(
+            values = (
                 self.resolve_lookup_value(sub_value, can_reuse, allow_joins)
                 for sub_value in value
             )
+            type_ = type(value)
+            if hasattr(type_, '_make'):  # namedtuple
+                return type_(*values)
+            return type_(values)
         return value
 
     def solve_lookup_type(self, lookup):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/queries/test_namedtuple_as_range_argument.py b/queries/test_namedtuple_as_range_argument.py
new file mode 100644
index 0000000000..29c29962c9
--- /dev/null
+++ b/queries/test_namedtuple_as_range_argument.py
@@ -0,0 +1,28 @@
+import collections
+from django.db.models import F
+from django.test import TestCase
+
+from .models import Number
+
+
+class RangeLookupWithNamedTupleTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.n1 = Number.objects.create(num=42, other_num=40)
+
+    def test_namedtuple_as_range_argument(self):
+        """
+        A named tuple containing an F() expression can be used as an argument
+        to a range lookup.
+        """
+        IntRange = collections.namedtuple('IntRange', ['near', 'far'])
+        # Using an F() expression forces Django to resolve the values in the
+        # tuple, which triggers the buggy code path in
+        # Query.resolve_lookup_value on the unpatched codebase.
+        value_range = IntRange(F('other_num'), 50)
+
+        # Before the patch, this filter call fails with:
+        # TypeError: __new__() missing 1 required positional argument: 'far'
+        # The patch fixes this by using ._make() for namedtuples.
+        qs = Number.objects.filter(num__range=value_range)
+        self.assertCountEqual(qs, [self.n1])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_namedtuple_as_range_argument
cat coverage.cover
git checkout 755dbf39fcdc491fe9b588358303e259c7750be4
git apply /root/pre_state.patch
