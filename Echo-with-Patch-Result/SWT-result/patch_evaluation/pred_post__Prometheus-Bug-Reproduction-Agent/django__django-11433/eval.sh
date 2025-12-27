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
diff --git a/tests/test_omitted_field_default_override.py b/tests/test_omitted_field_default_override.py
new file mode 100644
index 0000000000..01e389b89b
--- /dev/null
+++ b/tests/test_omitted_field_default_override.py
@@ -0,0 +1,62 @@
+from django import forms
+from django.db import models
+from django.test import TestCase
+
+
+class Story(models.Model):
+    """A model with a default value on its 'status' field."""
+    title = models.CharField(max_length=100)
+    # The 'status' field has a default that should be overridden by the form.
+    status = models.CharField(max_length=20, default='draft')
+
+    class Meta:
+        # app_label is required by Django's test runner to create the model.
+        app_label = 'model_forms'
+
+
+class StoryForm(forms.ModelForm):
+    """
+    A ModelForm where the clean() method for 'status' should override the
+    model's default value.
+    """
+    class Meta:
+        model = Story
+        fields = ['title', 'status']
+
+    def __init__(self, *args, **kwargs):
+        super().__init__(*args, **kwargs)
+        # The 'status' field is made optional so it can be omitted from the
+        # form submission, which is a necessary condition to trigger the bug.
+        self.fields['status'].required = False
+
+    def clean_status(self):
+        # This method provides a value for 'status' in the form's cleaned_data.
+        # This value should be used for the model instance, overriding the
+        # model's 'default' value.
+        return 'published'
+
+
+class OmittedFieldDefaultOverrideTest(TestCase):
+    """
+    Test case to ensure a ModelForm's cleaned_data overrides a model default.
+    """
+
+    def test_cleaned_value_overrides_model_default_for_omitted_field(self):
+        """
+        Tests that a value from a form's clean method is used instead of
+        a model field's default when the field is not in the submitted data.
+        """
+        # We pass a 'title' but omit the 'status' field in the data dict.
+        # This simulates a POST request where the 'status' field was not sent.
+        form = StoryForm(data={'title': 'A New Story'})
+
+        # The form is valid because clean_status() provides a valid value.
+        self.assertTrue(form.is_valid())
+
+        # The bug exists in the logic that constructs the model instance.
+        instance = form.save(commit=False)
+
+        # This assertion checks if the instance's 'status' is the value
+        # from clean_status() ('published') rather than the model's default
+        # ('draft'). This will FAIL on the old code and PASS on the new code.
+        self.assertEqual(instance.status, 'published')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_omitted_field_default_override
cat coverage.cover
git checkout 21b1d239125f1228e579b1ce8d94d4d5feadd2a6
git apply /root/pre_state.patch
