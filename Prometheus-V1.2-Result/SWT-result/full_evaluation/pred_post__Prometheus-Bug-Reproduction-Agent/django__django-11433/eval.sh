#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 21b1d239125f1228e579b1ce8d94d4d5feadd2a6 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 21b1d239125f1228e579b1ce8d94d4d5feadd2a6
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/forms/models.py b/django/forms/models.py
--- a/django/forms/models.py
+++ b/django/forms/models.py
@@ -48,8 +48,11 @@ def construct_instance(form, instance, fields=None, exclude=None):
             continue
         # Leave defaults for fields that aren't in POST data, except for
         # checkbox inputs because they don't appear in POST data if not checked.
-        if (f.has_default() and
-                form[f.name].field.widget.value_omitted_from_data(form.data, form.files, form.add_prefix(f.name))):
+        if (
+            f.has_default() and
+            form[f.name].field.widget.value_omitted_from_data(form.data, form.files, form.add_prefix(f.name)) and
+            cleaned_data.get(f.name) in form[f.name].field.empty_values
+        ):
             continue
         # Defer saving file-type fields until after the other fields, so a
         # callable upload_to can use the values from other fields.

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_forms/test_cleaned_data_overwrite.py b/tests/model_forms/test_cleaned_data_overwrite.py
new file mode 100644
index 0000000000..8d561958fb
--- /dev/null
+++ b/tests/model_forms/test_cleaned_data_overwrite.py
@@ -0,0 +1,31 @@
+import datetime
+
+from django import forms
+from django.test import TestCase
+
+from .models import PublicationDefaults
+
+
+class CleanedDataOverwriteTests(TestCase):
+    def test_cleaned_data_overwrites_model_default(self):
+        """
+        A model field's default value can be overwritten by a value from
+        the form's cleaned_data.
+        """
+        class PublicationDefaultsForm(forms.ModelForm):
+            class Meta:
+                model = PublicationDefaults
+                fields = ['title', 'mode']
+
+            def clean(self):
+                self.cleaned_data['mode'] = 'de'
+                return self.cleaned_data
+
+        # The form is submitted without a value for 'mode'. The model has a
+        # default value of 'di' for this field.
+        form = PublicationDefaultsForm({'title': 'A test'})
+        self.assertTrue(form.is_valid())
+        instance = form.save()
+        # The value from clean() ('de') should be used, not the model's
+        # default ('di').
+        self.assertEqual(instance.mode, 'de')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_forms.test_cleaned_data_overwrite
cat coverage.cover
git checkout 21b1d239125f1228e579b1ce8d94d4d5feadd2a6
git apply /root/pre_state.patch
