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
diff --git a/tests/test_model_choice_iterator_value.py b/tests/test_model_choice_iterator_value.py
new file mode 100644
index 0000000000..2fc4e29274
--- /dev/null
+++ b/tests/test_model_choice_iterator_value.py
@@ -0,0 +1,37 @@
+import json
+
+from django import forms
+from django.test import TestCase
+
+from .models import Category
+
+
+class ModelChoiceIteratorValueTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        cls.c1 = Category.objects.create(
+            pk=1, name='Entertainment', slug='entertainment', url='entertainment'
+        )
+
+    def test_modelchoiceiteratorvalue_is_hashable(self):
+        class ShowFieldsSelect(forms.Select):
+            show_fields = {
+                self.c1.pk: ['first_name', 'last_name'],
+            }
+
+            def create_option(self, name, value, label, selected, index, subindex=None, attrs=None):
+                option = super().create_option(
+                    name, value, label, selected, index, subindex=subindex, attrs=attrs
+                )
+                if value in self.show_fields:
+                    option['attrs']['data-fields'] = json.dumps(self.show_fields[value])
+                return option
+
+        class CategoryForm(forms.Form):
+            category = forms.ModelChoiceField(
+                queryset=Category.objects.all(),
+                widget=ShowFieldsSelect,
+            )
+
+        form = CategoryForm()
+        self.assertIn('data-fields', form.as_p())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_model_choice_iterator_value
cat coverage.cover
git checkout 903aaa35e5ceaa33bfc9b19b7f6da65ce5a91dd4
git apply /root/pre_state.patch
