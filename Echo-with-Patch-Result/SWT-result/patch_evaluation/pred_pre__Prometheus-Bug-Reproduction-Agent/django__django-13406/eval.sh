#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 84609b3205905097d7d3038d32e6101f012c0619 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 84609b3205905097d7d3038d32e6101f012c0619
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/queryset_pickle/test_pickled_queryset_values.py b/tests/queryset_pickle/test_pickled_queryset_values.py
new file mode 100644
index 0000000000..a09769f8b7
--- /dev/null
+++ b/tests/queryset_pickle/test_pickled_queryset_values.py
@@ -0,0 +1,42 @@
+import pickle
+
+from django.db import models
+from django.db.models import Sum
+from django.test import TestCase
+
+# The Toy model from the bug report, defined here to make the test
+# self-contained. The app_label is necessary for the test runner to handle
+# the model correctly.
+class Toy(models.Model):
+    name = models.CharField(max_length=16)
+    material = models.CharField(max_length=16)
+    price = models.PositiveIntegerField()
+
+    class Meta:
+        app_label = 'queryset_pickle'
+
+
+class PickledQuerysetValuesTests(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        Toy.objects.create(name='foo', price=10, material='wood')
+        Toy.objects.create(name='bar', price=20, material='plastic')
+        Toy.objects.create(name='baz', price=100, material='wood')
+
+    def test_pickled_values_queryset(self):
+        """
+        A queryset recreated from a pickled .query object from a
+        values() queryset should produce dictionaries, not model instances.
+        """
+        prices = Toy.objects.values('material').annotate(total_price=Sum('price'))
+        pickled_query = pickle.dumps(prices.query)
+        unpickled_query = pickle.loads(pickled_query)
+
+        prices_recreated = Toy.objects.all()
+        prices_recreated.query = unpickled_query
+
+        # Before the fix, this would raise an AttributeError when evaluating the
+        # queryset because it would incorrectly use ModelIterable instead of
+        # ValuesIterable, trying to create model instances from aggregated data.
+        # The assertion checks that the returned item is a dict as expected.
+        self.assertIsInstance(prices_recreated[0], dict)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queryset_pickle.test_pickled_queryset_values
cat coverage.cover
git checkout 84609b3205905097d7d3038d32e6101f012c0619
git apply /root/pre_state.patch
