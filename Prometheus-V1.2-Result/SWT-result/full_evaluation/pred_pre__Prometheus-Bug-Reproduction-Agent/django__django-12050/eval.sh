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
diff --git a/tests/lookup/test_exact_lookup_type_coercion.py b/tests/lookup/test_exact_lookup_type_coercion.py
new file mode 100644
index 0000000000..155ba69635
--- /dev/null
+++ b/tests/lookup/test_exact_lookup_type_coercion.py
@@ -0,0 +1,52 @@
+import pickle
+
+from django.db import models
+from django.test import TestCase
+
+
+# A minimal PickledField is required to demonstrate the bug, as it's one of
+# the few field types that distinguishes between a list and a tuple.
+class PickledField(models.BinaryField):
+    """A field that pickles Python objects for database storage."""
+
+    def get_prep_value(self, value):
+        """Pickle the value before sending it to the database."""
+        if value is not None:
+            value = pickle.dumps(value)
+        return super().get_prep_value(value)
+
+    def from_db_value(self, value, expression, connection):
+        """Unpickle the value when retrieving it from the database."""
+        if value is not None:
+            return pickle.loads(value)
+        return value
+
+
+class PickledModel(models.Model):
+    """A model using the PickledField for testing."""
+    field = PickledField()
+
+    class Meta:
+        # Add app_label to avoid "no such table" errors in standalone tests.
+        app_label = 'lookup'
+
+
+class ExactLookupTypeCoercionTest(TestCase):
+    """
+    Tests that list values in lookups are not incorrectly coerced to tuples.
+    """
+    @classmethod
+    def setUpTestData(cls):
+        """Create a test object with a list stored in a PickledField."""
+        cls.obj = PickledModel.objects.create(field=['value1', 'value2'])
+
+    def test_exact_lookup_preserves_list_type(self):
+        """
+        An exact lookup with a list should not coerce it into a tuple,
+        which would cause the lookup to fail for type-sensitive fields.
+        """
+        # This query will fail if the ['value1', 'value2'] list is coerced to a
+        # tuple, because the pickled representation of a list is different
+        # from that of a tuple.
+        qs = PickledModel.objects.filter(field=['value1', 'value2'])
+        self.assertEqual(qs.get(), self.obj)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 lookup.test_exact_lookup_type_coercion
cat coverage.cover
git checkout b93a0e34d9b9b99d41103782b7e7aeabf47517e3
git apply /root/pre_state.patch
