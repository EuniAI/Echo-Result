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
diff --git a/tests/modeladmin/test_radio_fields.py b/tests/modeladmin/test_radio_fields.py
new file mode 100644
index 0000000000..d8bbe84c46
--- /dev/null
+++ b/tests/modeladmin/test_radio_fields.py
@@ -0,0 +1,51 @@
+from datetime import date
+
+from django.contrib.admin.options import ModelAdmin, VERTICAL
+from django.contrib.admin.sites import AdminSite
+from django.test import TestCase
+
+from .models import Band, Concert
+
+
+class MockRequest:
+    pass
+
+
+class MockSuperUser:
+    def has_perm(self, perm, obj=None):
+        return True
+
+
+request = MockRequest()
+request.user = MockSuperUser()
+
+
+class RadioFieldEmptyLabelTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.band = Band.objects.create(
+            name="The Doors",
+            bio="",
+            sign_date=date(1965, 1, 1),
+        )
+
+    def test_radio_fields_override_empty_label(self):
+        """
+        A custom empty_label on a formfield is not overridden when the field
+        is displayed as a radio button.
+        """
+
+        class ConcertAdmin(ModelAdmin):
+            radio_fields = {"opening_band": VERTICAL}
+
+            def formfield_for_foreignkey(self, db_field, request, **kwargs):
+                if db_field.name == "opening_band":
+                    kwargs["empty_label"] = "I WANT TO SET MY OWN EMPTY LABEL"
+                return super().formfield_for_foreignkey(db_field, request, **kwargs)
+
+        ma = ConcertAdmin(Concert, AdminSite())
+        form = ma.get_form(request)
+        self.assertEqual(
+            form.base_fields["opening_band"].empty_label,
+            "I WANT TO SET MY OWN EMPTY LABEL",
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/options\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 modeladmin.test_radio_fields
cat coverage.cover
git checkout e0442a628eb480eac6a7888aed5a86f83499e299
git apply /root/pre_state.patch
