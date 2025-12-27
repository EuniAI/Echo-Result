#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 00ea883ef56fb5e092cbe4a6f7ff2e7470886ac4 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 00ea883ef56fb5e092cbe4a6f7ff2e7470886ac4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/reverse_related.py b/django/db/models/fields/reverse_related.py
--- a/django/db/models/fields/reverse_related.py
+++ b/django/db/models/fields/reverse_related.py
@@ -310,7 +310,7 @@ def __init__(self, field, to, related_name=None, related_query_name=None,
     def identity(self):
         return super().identity + (
             self.through,
-            self.through_fields,
+            make_hashable(self.through_fields),
             self.db_constraint,
         )
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/proxy_models/test_checks.py b/tests/proxy_models/test_checks.py
new file mode 100644
index 0000000000..9ce9fdad1e
--- /dev/null
+++ b/tests/proxy_models/test_checks.py
@@ -0,0 +1,50 @@
+from django.core import checks
+from django.db import models
+from django.test import SimpleTestCase
+from django.test.utils import isolate_apps
+
+
+class M2MProxyCheckTests(SimpleTestCase):
+    @isolate_apps("proxy_models")
+    def test_m2m_through_fields_hashable(self):
+        """
+        Check that ManyToManyRel.through_fields is made hashable for proxy
+        model checks (#32765).
+        """
+
+        class Parent(models.Model):
+            name = models.CharField(max_length=256)
+
+            class Meta:
+                app_label = "proxy_models"
+
+        class ProxyParent(Parent):
+            class Meta:
+                proxy = True
+                app_label = "proxy_models"
+
+        class Child(models.Model):
+            parent = models.ForeignKey(Parent, on_delete=models.CASCADE)
+            many_to_many_field = models.ManyToManyField(
+                to=Parent,
+                through="ManyToManyModel",
+                through_fields=["child", "parent"],
+                related_name="something",
+            )
+
+            class Meta:
+                app_label = "proxy_models"
+
+        class ManyToManyModel(models.Model):
+            parent = models.ForeignKey(
+                Parent, on_delete=models.CASCADE, related_name="+"
+            )
+            child = models.ForeignKey(Child, on_delete=models.CASCADE, related_name="+")
+            second_child = models.ForeignKey(
+                Child, on_delete=models.CASCADE, null=True, default=None
+            )
+
+            class Meta:
+                app_label = "proxy_models"
+
+        self.assertEqual(ProxyParent.check(), [])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/reverse_related\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 proxy_models.test_checks
cat coverage.cover
git checkout 00ea883ef56fb5e092cbe4a6f7ff2e7470886ac4
git apply /root/pre_state.patch
