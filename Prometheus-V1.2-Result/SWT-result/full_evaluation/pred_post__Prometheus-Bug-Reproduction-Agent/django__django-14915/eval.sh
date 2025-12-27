#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 903aaa35e5ceaa33bfc9b19b7f6da65ce5a91dd4 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 903aaa35e5ceaa33bfc9b19b7f6da65ce5a91dd4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/forms/models.py b/django/forms/models.py
--- a/django/forms/models.py
+++ b/django/forms/models.py
@@ -1166,6 +1166,9 @@ def __init__(self, value, instance):
     def __str__(self):
         return str(self.value)
 
+    def __hash__(self):
+        return hash(self.value)
+
     def __eq__(self, other):
         if isinstance(other, ModelChoiceIteratorValue):
             other = other.value

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_forms/test_select_widget_bugs.py b/tests/model_forms/test_select_widget_bugs.py
new file mode 100644
index 0000000000..4b85ebe004
--- /dev/null
+++ b/tests/model_forms/test_select_widget_bugs.py
@@ -0,0 +1,39 @@
+from django import forms
+from django.test import TestCase
+
+from .models import Category
+
+
+class SelectWidgetBugsTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.cat = Category.objects.create(name='Test Category', slug='test-category', url='test-category')
+
+    def test_modelchoiceiteratorvalue_unhashable(self):
+        """
+        A ModelChoiceIteratorValue should be hashable to allow it to be used
+        in collections.
+        """
+        class CustomSelect(forms.Select):
+            def __init__(self, *args, **kwargs):
+                self.show_fields = kwargs.pop('show_fields', {})
+                super().__init__(*args, **kwargs)
+
+            def create_option(self, name, value, label, selected, index, subindex=None, attrs=None):
+                # This check fails with "TypeError: unhashable type:
+                # 'ModelChoiceIteratorValue'" because `value` is an object,
+                # not a simple PK.
+                if value in self.show_fields:
+                    pass
+                return super().create_option(name, value, label, selected, index, subindex, attrs)
+
+        class CategoryForm(forms.Form):
+            category = forms.ModelChoiceField(
+                queryset=Category.objects.all(),
+                widget=CustomSelect(show_fields={self.cat.pk: ['field']}),
+            )
+
+        form = CategoryForm()
+        # Rendering the form calls create_option() for each choice. This test
+        # will fail with a TypeError before the fix and pass after.
+        form.as_p()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_forms.test_select_widget_bugs
cat coverage.cover
git checkout 903aaa35e5ceaa33bfc9b19b7f6da65ce5a91dd4
git apply /root/pre_state.patch
