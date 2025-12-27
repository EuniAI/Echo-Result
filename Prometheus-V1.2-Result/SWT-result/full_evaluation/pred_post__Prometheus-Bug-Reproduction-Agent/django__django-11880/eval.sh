#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 06909fe084f87a65459a83bd69d7cdbe4fce9a7c >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 06909fe084f87a65459a83bd69d7cdbe4fce9a7c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/forms/fields.py b/django/forms/fields.py
--- a/django/forms/fields.py
+++ b/django/forms/fields.py
@@ -199,6 +199,7 @@ def __deepcopy__(self, memo):
         result = copy.copy(self)
         memo[id(self)] = result
         result.widget = copy.deepcopy(self.widget, memo)
+        result.error_messages = self.error_messages.copy()
         result.validators = self.validators[:]
         return result
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/forms_tests/field_tests/test_basic.py b/tests/forms_tests/field_tests/test_basic.py
new file mode 100644
index 0000000000..9d12aa3b3a
--- /dev/null
+++ b/tests/forms_tests/field_tests/test_basic.py
@@ -0,0 +1,46 @@
+import copy
+from django.forms import ChoiceField, Field, Form, Select
+from django.test import SimpleTestCase
+
+
+class BasicFieldsTests(SimpleTestCase):
+
+    def test_field_sets_widget_is_required(self):
+        self.assertTrue(Field(required=True).widget.is_required)
+        self.assertFalse(Field(required=False).widget.is_required)
+
+    def test_cooperative_multiple_inheritance(self):
+        class A:
+            def __init__(self):
+                self.class_a_var = True
+                super().__init__()
+
+        class ComplexField(Field, A):
+            def __init__(self):
+                super().__init__()
+
+        f = ComplexField()
+        self.assertTrue(f.class_a_var)
+
+    def test_field_deepcopies_widget_instance(self):
+        class CustomChoiceField(ChoiceField):
+            widget = Select(attrs={'class': 'my-custom-class'})
+
+        class TestForm(Form):
+            field1 = CustomChoiceField(choices=[])
+            field2 = CustomChoiceField(choices=[])
+
+        f = TestForm()
+        f.fields['field1'].choices = [('1', '1')]
+        f.fields['field2'].choices = [('2', '2')]
+        self.assertEqual(f.fields['field1'].widget.choices, [('1', '1')])
+        self.assertEqual(f.fields['field2'].widget.choices, [('2', '2')])
+
+    def test_deepcopy_error_messages(self):
+        """
+        __deepcopy__() on a Field doesn't deepcopy error_messages.
+        """
+        f1 = Field(error_messages={'required': 'original message'})
+        f2 = copy.deepcopy(f1)
+        f2.error_messages['required'] = 'modified message'
+        self.assertEqual(f1.error_messages['required'], 'original message')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/fields\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 forms_tests.field_tests.test_basic
cat coverage.cover
git checkout 06909fe084f87a65459a83bd69d7cdbe4fce9a7c
git apply /root/pre_state.patch
