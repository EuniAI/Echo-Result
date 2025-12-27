#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5b884d45ac5b76234eca614d90c83b347294c332 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5b884d45ac5b76234eca614d90c83b347294c332
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/admin/options.py b/django/contrib/admin/options.py
--- a/django/contrib/admin/options.py
+++ b/django/contrib/admin/options.py
@@ -249,17 +249,25 @@ def formfield_for_manytomany(self, db_field, request, **kwargs):
             return None
         db = kwargs.get('using')
 
-        autocomplete_fields = self.get_autocomplete_fields(request)
-        if db_field.name in autocomplete_fields:
-            kwargs['widget'] = AutocompleteSelectMultiple(db_field.remote_field, self.admin_site, using=db)
-        elif db_field.name in self.raw_id_fields:
-            kwargs['widget'] = widgets.ManyToManyRawIdWidget(db_field.remote_field, self.admin_site, using=db)
-        elif db_field.name in [*self.filter_vertical, *self.filter_horizontal]:
-            kwargs['widget'] = widgets.FilteredSelectMultiple(
-                db_field.verbose_name,
-                db_field.name in self.filter_vertical
-            )
-
+        if 'widget' not in kwargs:
+            autocomplete_fields = self.get_autocomplete_fields(request)
+            if db_field.name in autocomplete_fields:
+                kwargs['widget'] = AutocompleteSelectMultiple(
+                    db_field.remote_field,
+                    self.admin_site,
+                    using=db,
+                )
+            elif db_field.name in self.raw_id_fields:
+                kwargs['widget'] = widgets.ManyToManyRawIdWidget(
+                    db_field.remote_field,
+                    self.admin_site,
+                    using=db,
+                )
+            elif db_field.name in [*self.filter_vertical, *self.filter_horizontal]:
+                kwargs['widget'] = widgets.FilteredSelectMultiple(
+                    db_field.verbose_name,
+                    db_field.name in self.filter_vertical
+                )
         if 'queryset' not in kwargs:
             queryset = self.get_field_queryset(db, db_field, request)
             if queryset is not None:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/modeladmin/test_formfield_for_manytomany_override.py b/tests/modeladmin/test_formfield_for_manytomany_override.py
new file mode 100644
index 0000000000..f63b0d3457
--- /dev/null
+++ b/tests/modeladmin/test_formfield_for_manytomany_override.py
@@ -0,0 +1,67 @@
+from django import forms
+from django.contrib.admin.options import ModelAdmin
+from django.contrib.admin.sites import AdminSite
+from django.db import models
+from django.test import TestCase
+
+
+# Minimal models to make the test self-contained.
+# Using an app_label of 'modeladmin' which likely exists in the test setup.
+class Band(models.Model):
+    name = models.CharField(max_length=100)
+
+    class Meta:
+        app_label = 'modeladmin'
+
+
+class Song(models.Model):
+    title = models.CharField(max_length=100)
+    featuring = models.ManyToManyField(Band)
+
+    class Meta:
+        app_label = 'modeladmin'
+
+
+# Mock request object
+class MockRequest:
+    def __init__(self, user=None):
+        self.user = user
+
+
+class MockSuperUser:
+    def has_perm(self, perm, obj=None):
+        return True
+
+
+request = MockRequest(user=MockSuperUser())
+
+
+class FormfieldForManyToManyOverrideTest(TestCase):
+    """
+    Tests that a custom widget in formfield_for_manytomany is not overridden.
+    """
+    def test_formfield_for_manytomany_widget_override(self):
+        """
+        A widget passed to formfield_for_manytomany() shouldn't be overridden by
+        raw_id_fields.
+        """
+        class CustomSelectMultiple(forms.SelectMultiple):
+            pass
+
+        class SongAdmin(ModelAdmin):
+            raw_id_fields = ('featuring',)
+
+        site = AdminSite()
+        # The admin site needs to be aware of the related model to build the widget.
+        site.register(Band)
+        ma = SongAdmin(Song, site)
+        db_field = Song._meta.get_field('featuring')
+
+        form_field = ma.formfield_for_manytomany(
+            db_field,
+            request,
+            widget=CustomSelectMultiple()
+        )
+        # The bug is that raw_id_fields causes the custom widget to be
+        # overwritten. This assertion will fail before the fix.
+        self.assertIsInstance(form_field.widget, CustomSelectMultiple)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/options\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 modeladmin.test_formfield_for_manytomany_override
cat coverage.cover
git checkout 5b884d45ac5b76234eca614d90c83b347294c332
git apply /root/pre_state.patch
