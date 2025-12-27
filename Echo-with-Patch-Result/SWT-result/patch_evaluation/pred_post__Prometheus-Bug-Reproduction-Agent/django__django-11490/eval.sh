#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a7038adbd02c916315b16939b835f021c2ee8880 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a7038adbd02c916315b16939b835f021c2ee8880
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/compiler.py b/django/db/models/sql/compiler.py
--- a/django/db/models/sql/compiler.py
+++ b/django/db/models/sql/compiler.py
@@ -426,6 +426,7 @@ def get_combinator_sql(self, combinator, all):
                 # must have the same columns list. Set the selects defined on
                 # the query on all combined queries, if not already set.
                 if not compiler.query.values_select and self.query.values_select:
+                    compiler.query = compiler.query.clone()
                     compiler.query.set_values((
                         *self.query.extra_select,
                         *self.query.values_select,

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/queries/test_composed_query_values.py b/tests/queries/test_composed_query_values.py
new file mode 100644
index 0000000000..95fe86ff28
--- /dev/null
+++ b/tests/queries/test_composed_query_values.py
@@ -0,0 +1,22 @@
+from django.apps import apps
+from django.test import TestCase, skipUnlessDBFeature
+
+
+@skipUnlessDBFeature('supports_select_union')
+class ComposedQueryValuesTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        ReservedName = apps.get_model('queries', 'ReservedName')
+        ReservedName.objects.create(name='a', order=2)
+
+    def test_composed_queryset_values_columns_change(self):
+        """
+        A composed queryset, when evaluated, shouldn't mutate the
+        Query objects of the composing querysets.
+        """
+        ReservedName = apps.get_model('queries', 'ReservedName')
+        qs = ReservedName.objects.all()
+        # This evaluation of a composed queryset shouldn't affect qs.
+        list(qs.union(qs).values_list('name', 'order'))
+        # This second evaluation should not be affected by the first.
+        self.assertEqual(qs.union(qs).values_list('order').get(), (2,))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/compiler\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queries.test_composed_query_values
cat coverage.cover
git checkout a7038adbd02c916315b16939b835f021c2ee8880
git apply /root/pre_state.patch
