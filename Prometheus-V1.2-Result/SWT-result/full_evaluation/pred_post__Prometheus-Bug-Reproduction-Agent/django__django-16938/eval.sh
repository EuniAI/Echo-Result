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
diff --git a/tests/serializers/test_m2m_select_related_serialization.py b/tests/serializers/test_m2m_select_related_serialization.py
new file mode 100644
index 0000000000..6e59b8953a
--- /dev/null
+++ b/tests/serializers/test_m2m_select_related_serialization.py
@@ -0,0 +1,45 @@
+from django.core import serializers
+from django.core.exceptions import FieldError
+from django.db import models
+from django.test import TestCase
+
+
+# Models inspired by the bug report.
+class TestTagManager(models.Manager):
+    def get_queryset(self):
+        return super().get_queryset().select_related("master")
+
+
+class TestTagMaster(models.Model):
+    name = models.CharField(max_length=120)
+
+
+class TestTag(models.Model):
+    objects = TestTagManager()
+    name = models.CharField(max_length=120)
+    master = models.ForeignKey(
+        TestTagMaster, on_delete=models.SET_NULL, null=True, blank=True
+    )
+
+
+class TestModel(models.Model):
+    name = models.CharField(max_length=120)
+    tags = models.ManyToManyField(TestTag, blank=True)
+
+
+class SerializationM2MSelectRelatedTests(TestCase):
+    def test_serialization_of_m2m_with_custom_manager_using_select_related(self):
+        """
+        Tests that serializing a M2M relation with a custom manager that
+        uses select_related does not cause a FieldError. This test will fail
+        until the bug is fixed.
+        """
+        tag_master = TestTagMaster.objects.create(name="master")
+        tag = TestTag.objects.create(name="tag", master=tag_master)
+        test_obj = TestModel.objects.create(name="test")
+        test_obj.tags.add(tag)
+
+        # This call raises a FieldError due to the bug, which will cause this
+        # test to fail. Once the bug is fixed, this line will execute
+        # without error, and the test will pass.
+        serializers.serialize("json", [test_obj])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/serializers/xml_serializer\.py|django/core/serializers/python\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 serializers.test_m2m_select_related_serialization
cat coverage.cover
git checkout 1136aa5005f0ae70fea12796b7e37d6f027b9263
git apply /root/pre_state.patch
