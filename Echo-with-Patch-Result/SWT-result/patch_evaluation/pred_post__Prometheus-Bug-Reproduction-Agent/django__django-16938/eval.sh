#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1136aa5005f0ae70fea12796b7e37d6f027b9263 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1136aa5005f0ae70fea12796b7e37d6f027b9263
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/serializers/python.py b/django/core/serializers/python.py
--- a/django/core/serializers/python.py
+++ b/django/core/serializers/python.py
@@ -79,7 +79,9 @@ def m2m_value(value):
                     return self._value_from_field(value, value._meta.pk)
 
                 def queryset_iterator(obj, field):
-                    return getattr(obj, field.name).only("pk").iterator()
+                    return (
+                        getattr(obj, field.name).select_related().only("pk").iterator()
+                    )
 
             m2m_iter = getattr(obj, "_prefetched_objects_cache", {}).get(
                 field.name,
diff --git a/django/core/serializers/xml_serializer.py b/django/core/serializers/xml_serializer.py
--- a/django/core/serializers/xml_serializer.py
+++ b/django/core/serializers/xml_serializer.py
@@ -155,7 +155,9 @@ def handle_m2m(value):
                     self.xml.addQuickElement("object", attrs={"pk": str(value.pk)})
 
                 def queryset_iterator(obj, field):
-                    return getattr(obj, field.name).only("pk").iterator()
+                    return (
+                        getattr(obj, field.name).select_related().only("pk").iterator()
+                    )
 
             m2m_iter = getattr(obj, "_prefetched_objects_cache", {}).get(
                 field.name,

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/serializers/test_custom_managers.py b/tests/serializers/test_custom_managers.py
new file mode 100644
index 0000000000..07c6707e1b
--- /dev/null
+++ b/tests/serializers/test_custom_managers.py
@@ -0,0 +1,55 @@
+import json
+
+from django.core import serializers
+from django.db import models
+from django.test import TestCase
+
+
+# Models from the ticket
+class TestTagManager(models.Manager):
+    def get_queryset(self):
+        qs = super().get_queryset()
+        qs = qs.select_related("master")
+        return qs
+
+
+class TestTagMaster(models.Model):
+    name = models.CharField(max_length=120)
+
+    class Meta:
+        app_label = "serializers"
+
+
+class TestTag(models.Model):
+    objects = TestTagManager()
+    name = models.CharField(max_length=120)
+    master = models.ForeignKey(TestTagMaster, on_delete=models.SET_NULL, null=True)
+
+    class Meta:
+        app_label = "serializers"
+
+
+class Test(models.Model):
+    name = models.CharField(max_length=120)
+    tags = models.ManyToManyField(TestTag, blank=True)
+
+    class Meta:
+        app_label = "serializers"
+
+
+class CustomManagerTests(TestCase):
+    def test_m2m_select_related_custom_manager(self):
+        """
+        Test that serializing an m2m relation to a model with a custom
+        manager using select_related() doesn't cause a FieldError.
+        """
+        tag_master = TestTagMaster.objects.create(name="master")
+        tag = TestTag.objects.create(name="tag", master=tag_master)
+        test = Test.objects.create(name="test")
+        test.tags.add(tag)
+
+        # This call should not raise a FieldError.
+        data = serializers.serialize("json", [test])
+        # A minimal assertion to confirm serialization ran and produced
+        # valid JSON with the expected M2M relation.
+        self.assertIn('"tags": [%d]' % tag.pk, data)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/serializers/xml_serializer\.py|django/core/serializers/python\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 serializers.test_custom_managers
cat coverage.cover
git checkout 1136aa5005f0ae70fea12796b7e37d6f027b9263
git apply /root/pre_state.patch
