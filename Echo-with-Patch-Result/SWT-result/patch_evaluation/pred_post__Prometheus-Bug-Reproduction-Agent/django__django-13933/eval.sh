#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 42e8cf47c7ee2db238bf91197ea398126c546741 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 42e8cf47c7ee2db238bf91197ea398126c546741
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/forms/models.py b/django/forms/models.py
--- a/django/forms/models.py
+++ b/django/forms/models.py
@@ -1284,7 +1284,11 @@ def to_python(self, value):
                 value = getattr(value, key)
             value = self.queryset.get(**{key: value})
         except (ValueError, TypeError, self.queryset.model.DoesNotExist):
-            raise ValidationError(self.error_messages['invalid_choice'], code='invalid_choice')
+            raise ValidationError(
+                self.error_messages['invalid_choice'],
+                code='invalid_choice',
+                params={'value': value},
+            )
         return value
 
     def validate(self, value):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_modelchoicefield.py b/tests/test_modelchoicefield.py
new file mode 100644
index 0000000000..28f3a97819
--- /dev/null
+++ b/tests/test_modelchoicefield.py
@@ -0,0 +1,22 @@
+from django import forms
+from django.core.exceptions import ValidationError
+from django.test import TestCase
+
+from .models import Category
+
+
+class ModelChoiceFieldTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.cat = Category.objects.create(name='Test Category', slug='test-cat', url='test-cat')
+
+    def test_invalid_choice_error_message(self):
+        """
+        When an invalid choice is provided to a ModelChoiceField, the
+        ValidationError message should contain the invalid value.
+        """
+        field = forms.ModelChoiceField(queryset=Category.objects.all())
+        invalid_pk = 500
+        msg = f"['Select a valid choice. {invalid_pk} is not one of the available choices.']"
+        with self.assertRaisesMessage(ValidationError, msg):
+            field.clean(invalid_pk)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_modelchoicefield
cat coverage.cover
git checkout 42e8cf47c7ee2db238bf91197ea398126c546741
git apply /root/pre_state.patch
