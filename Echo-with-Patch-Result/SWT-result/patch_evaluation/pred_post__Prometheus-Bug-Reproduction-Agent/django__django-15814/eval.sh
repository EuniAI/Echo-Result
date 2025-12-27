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
diff --git a/tests/proxy_models/test_select_related_only_crash.py b/tests/proxy_models/test_select_related_only_crash.py
new file mode 100644
index 0000000000..9e6cdb462c
--- /dev/null
+++ b/tests/proxy_models/test_select_related_only_crash.py
@@ -0,0 +1,44 @@
+from django.db import models
+from django.test import TestCase
+
+# These models should be added to a file like `tests/proxy_models/models.py`
+# to ensure they are part of a correctly configured application.
+class CustomModelForProxy(models.Model):
+    name = models.CharField(max_length=16)
+
+
+class ProxyCustomModelForProxy(CustomModelForProxy):
+    class Meta:
+        proxy = True
+
+
+class AnotherModelForProxy(models.Model):
+    custom = models.ForeignKey(
+        ProxyCustomModelForProxy,
+        on_delete=models.SET_NULL,
+        null=True,
+        blank=True,
+    )
+
+
+# This test class should be added to `tests/proxy_models/tests.py`.
+class ProxyModelSelectRelatedOnlyCrashTest(TestCase):
+    def test_select_related_only_on_proxy_model_fk(self):
+        """
+        Tests that .only() after .select_related() on a proxy model FK
+        crashes with ValueError.
+        """
+        # Create instances of the models.
+        custom = CustomModelForProxy.objects.create(name="custom")
+        AnotherModelForProxy.objects.create(custom=custom)
+
+        # This is the exact query from the bug report that causes the crash.
+        # The list() call forces the queryset to be evaluated. Before the fix,
+        # this test will fail with an unhandled `ValueError: 'id' is not in
+        # list`. After the fix, it will run without error, and the test will
+        # pass.
+        list(
+            AnotherModelForProxy.objects.select_related("custom")
+            .only("custom__name")
+            .all()
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/query\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 proxy_models.test_select_related_only_crash
cat coverage.cover
git checkout 5eb6a2b33d70b9889e1cafa12594ad6f80773d3a
git apply /root/pre_state.patch
