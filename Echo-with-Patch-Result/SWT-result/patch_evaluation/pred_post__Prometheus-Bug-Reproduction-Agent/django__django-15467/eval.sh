#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e0442a628eb480eac6a7888aed5a86f83499e299 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e0442a628eb480eac6a7888aed5a86f83499e299
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admin/options.py b/django/contrib/admin/options.py
--- a/django/contrib/admin/options.py
+++ b/django/contrib/admin/options.py
@@ -269,7 +269,9 @@ def formfield_for_foreignkey(self, db_field, request, **kwargs):
                         "class": get_ul_class(self.radio_fields[db_field.name]),
                     }
                 )
-                kwargs["empty_label"] = _("None") if db_field.blank else None
+                kwargs["empty_label"] = (
+                    kwargs.get("empty_label", _("None")) if db_field.blank else None
+                )
 
         if "queryset" not in kwargs:
             queryset = self.get_field_queryset(db, db_field, request)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/django/tests/admin_views/test_radio_fields_custom_empty_label.py b/django/tests/admin_views/test_radio_fields_custom_empty_label.py
new file mode 100644
index 0000000000..8acdba2772
--- /dev/null
+++ b/django/tests/admin_views/test_radio_fields_custom_empty_label.py
@@ -0,0 +1,68 @@
+import unittest
+
+from django.contrib import admin
+from django.contrib.admin.options import VERTICAL
+from django.contrib.auth.models import User
+from django.db import models
+from django.test import RequestFactory, TestCase
+
+
+# Models needed for the test
+class Band(models.Model):
+    name = models.CharField(max_length=100)
+
+    def __str__(self):
+        return self.name
+
+    class Meta:
+        app_label = "admin_views"
+
+
+class Concert(models.Model):
+    opening_band = models.ForeignKey(
+        Band,
+        models.CASCADE,
+        related_name="opening_concerts",
+        blank=True,
+        null=True,
+    )
+
+    class Meta:
+        app_label = "admin_views"
+
+
+class RadioFieldsCustomEmptyLabelTest(TestCase):
+    """
+    Tests for custom empty_label with radio_fields in ModelAdmin.
+    """
+
+    factory = RequestFactory()
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.band = Band.objects.create(name="The Doors")
+        cls.user = User.objects.create_superuser(
+            "admin", "admin@example.com", "password"
+        )
+
+    def test_foreign_key_radio_field_custom_empty_label(self):
+        """
+        A custom empty_label on a ForeignKey radio field is not overridden.
+        """
+        site = admin.AdminSite()
+        request = self.factory.get("/")
+        request.user = self.user
+
+        class ConcertAdmin(admin.ModelAdmin):
+            radio_fields = {"opening_band": VERTICAL}
+
+            def formfield_for_foreignkey(self, db_field, request, **kwargs):
+                if db_field.name == "opening_band":
+                    kwargs["empty_label"] = "My custom empty label"
+                return super().formfield_for_foreignkey(db_field, request, **kwargs)
+
+        ma = ConcertAdmin(Concert, site)
+        form = ma.get_form(request)
+        self.assertEqual(
+            form.base_fields["opening_band"].empty_label, "My custom empty label"
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/options\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 django.tests.admin_views.test_radio_fields_custom_empty_label
cat coverage.cover
git checkout e0442a628eb480eac6a7888aed5a86f83499e299
git apply /root/pre_state.patch
