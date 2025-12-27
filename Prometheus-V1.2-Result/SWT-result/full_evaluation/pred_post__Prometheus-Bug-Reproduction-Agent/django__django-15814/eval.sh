#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5eb6a2b33d70b9889e1cafa12594ad6f80773d3a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5eb6a2b33d70b9889e1cafa12594ad6f80773d3a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/query.py b/django/db/models/sql/query.py
--- a/django/db/models/sql/query.py
+++ b/django/db/models/sql/query.py
@@ -748,6 +748,7 @@ def deferred_to_data(self, target):
                     cur_model = source.related_model
                 else:
                     cur_model = source.remote_field.model
+                cur_model = cur_model._meta.concrete_model
                 opts = cur_model._meta
                 # Even if we're "just passing through" this model, we must add
                 # both the current model's pk and the related reference field

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/select_related/test_proxy_model_select_related_only_crash.py b/tests/select_related/test_proxy_model_select_related_only_crash.py
new file mode 100644
index 0000000000..aa5b8f975d
--- /dev/null
+++ b/tests/select_related/test_proxy_model_select_related_only_crash.py
@@ -0,0 +1,37 @@
+from django.db import models
+from django.test import TestCase
+
+
+# Models defined to exactly match the structure from the bug report.
+# A simple concrete model.
+class CustomModel(models.Model):
+    name = models.CharField(max_length=16)
+
+
+# A proxy for the concrete model.
+class ProxyCustomModel(CustomModel):
+    class Meta:
+        proxy = True
+
+
+# A model with a ForeignKey to the proxy model.
+class AnotherModel(models.Model):
+    custom = models.ForeignKey(ProxyCustomModel, on_delete=models.CASCADE)
+
+
+class ProxyModelSelectRelatedOnlyCrashTest(TestCase):
+    def test_select_related_only_on_proxy_fk_crashes(self):
+        """
+        Tests that select_related().only() on a FK to a proxy model crashes.
+        """
+        custom_obj = CustomModel.objects.create(name="test")
+        AnotherModel.objects.create(custom=custom_obj)
+
+        # This query targets a field on the related model through the proxy FK.
+        qs = AnotherModel.objects.select_related("custom").only("custom__name")
+
+        # The list() call triggers query execution and should raise a
+        # "ValueError: 'id' is not in list" because the proxy model's meta
+        # is used instead of the concrete model's meta.
+        # When fixed, this will not crash and the assertion will pass.
+        self.assertEqual(len(list(qs)), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 select_related.test_proxy_model_select_related_only_crash
cat coverage.cover
git checkout 5eb6a2b33d70b9889e1cafa12594ad6f80773d3a
git apply /root/pre_state.patch
