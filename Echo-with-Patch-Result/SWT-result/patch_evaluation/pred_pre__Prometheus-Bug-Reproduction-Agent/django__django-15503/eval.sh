#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 859a87d873ce7152af73ab851653b4e1c3ffea4c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 859a87d873ce7152af73ab851653b4e1c3ffea4c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_fields/test_jsonfield_has_key_numeric.py b/tests/model_fields/test_jsonfield_has_key_numeric.py
new file mode 100644
index 0000000000..888e074ac5
--- /dev/null
+++ b/tests/model_fields/test_jsonfield_has_key_numeric.py
@@ -0,0 +1,26 @@
+from django.db import models
+from django.test import TestCase, skipUnlessDBFeature
+
+
+class JSONFieldModel(models.Model):
+    data = models.JSONField()
+
+    class Meta:
+        app_label = "model_fields"
+
+
+@skipUnlessDBFeature("supports_json_field")
+class JSONFieldHasKeyNumericTest(TestCase):
+    def test_has_key_numeric_key(self):
+        """
+        The has_key, has_keys, and has_any_keys lookups should work with
+        numeric keys.
+        """
+        obj = JSONFieldModel.objects.create(data={"1111": "bar", "2222": "baz"})
+        self.assertSequenceEqual(JSONFieldModel.objects.filter(data__has_key="1111"), [obj])
+        self.assertSequenceEqual(
+            JSONFieldModel.objects.filter(data__has_keys=["1111", "2222"]), [obj]
+        )
+        self.assertSequenceEqual(
+            JSONFieldModel.objects.filter(data__has_any_keys=["1111", "3333"]), [obj]
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/json\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.test_jsonfield_has_key_numeric
cat coverage.cover
git checkout 859a87d873ce7152af73ab851653b4e1c3ffea4c
git apply /root/pre_state.patch
