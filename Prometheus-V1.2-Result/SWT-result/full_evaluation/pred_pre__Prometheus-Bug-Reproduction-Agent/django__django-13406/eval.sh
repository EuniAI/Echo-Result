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
diff --git a/tests/queryset_pickle/test_values_annotation.py b/tests/queryset_pickle/test_values_annotation.py
new file mode 100644
index 0000000000..c7eb0b8acf
--- /dev/null
+++ b/tests/queryset_pickle/test_values_annotation.py
@@ -0,0 +1,43 @@
+import pickle
+
+from django.db import models
+from django.db.models import Sum
+from django.test import TestCase
+
+# The bug report uses a `Toy` model which is not in the provided context.
+# To make the test self-contained, we define it here.
+# In a real Django project, this would be in a `models.py` file.
+class Toy(models.Model):
+    name = models.CharField(max_length=16)
+    material = models.CharField(max_length=16)
+    price = models.PositiveIntegerField()
+
+    class Meta:
+        app_label = 'queryset_pickle'
+
+
+class PickleabilityTestCase(TestCase):
+    # The models need to be available to the test runner.
+    # We assume the 'queryset_pickle' app is configured in INSTALLED_APPS.
+
+    def test_pickle_values_queryset_with_annotation(self):
+        """
+        Tests that a values() queryset with an annotation can be
+        recreated from a pickled query object.
+        """
+        Toy.objects.create(name='foo', price=10, material='wood')
+        Toy.objects.create(name='bar', price=20, material='plastic')
+        Toy.objects.create(name='baz', price=100, material='wood')
+
+        # This queryset returns dicts: [{'material': 'plastic', 'total_price': 20}, ...]
+        prices = Toy.objects.values('material').annotate(total_price=Sum('price'))
+
+        # Recreate the queryset from a pickled query, as described in the bug.
+        prices2 = Toy.objects.all()
+        prices2.query = pickle.loads(pickle.dumps(prices.query))
+
+        # The bug is that `prices2` attempts to return model instances instead of dicts.
+        # This causes an AttributeError when the queryset is evaluated, because the
+        # data from the GROUP BY query doesn't match the model's fields.
+        # The minimal assertion is to check the type of the returned item.
+        self.assertIs(type(prices2[0]), dict)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 queryset_pickle.test_values_annotation
cat coverage.cover
git checkout 84609b3205905097d7d3038d32e6101f012c0619
git apply /root/pre_state.patch
