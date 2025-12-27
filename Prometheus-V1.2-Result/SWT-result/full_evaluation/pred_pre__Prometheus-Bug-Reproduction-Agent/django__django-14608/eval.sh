#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7f33c1e22dbc34a7afae7967783725b10f1f13b1 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7f33c1e22dbc34a7afae7967783725b10f1f13b1
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/forms_tests/tests/test_formset_non_form_errors.py b/tests/forms_tests/tests/test_formset_non_form_errors.py
new file mode 100644
index 0000000000..a656ca94e7
--- /dev/null
+++ b/tests/forms_tests/tests/test_formset_non_form_errors.py
@@ -0,0 +1,45 @@
+from django.core.exceptions import ValidationError
+from django.forms import (
+    CharField,
+    Form,
+)
+from django.forms.formsets import BaseFormSet, formset_factory
+from django.test import SimpleTestCase
+
+
+class FavoriteDrinkForm(Form):
+    name = CharField()
+
+
+class BaseFavoriteDrinksFormSet(BaseFormSet):
+    def clean(self):
+        seen_drinks = []
+        for drink in self.cleaned_data:
+            if drink.get("name") in seen_drinks:
+                raise ValidationError("You may only specify a drink once.")
+            if drink.get("name"):
+                seen_drinks.append(drink.get("name"))
+
+
+FavoriteDrinksFormSet = formset_factory(
+    FavoriteDrinkForm, formset=BaseFavoriteDrinksFormSet, extra=2
+)
+
+
+class FormsetNonFormErrorTest(SimpleTestCase):
+    def test_non_form_errors_have_nonform_class(self):
+        """
+        Formset non-form errors should be rendered with a 'nonform' CSS class.
+        """
+        data = {
+            "form-TOTAL_FORMS": "2",
+            "form-INITIAL_FORMS": "0",
+            "form-0-name": "Gin",
+            "form-1-name": "Gin",  # Duplicate
+        }
+        formset = FavoriteDrinksFormSet(data, prefix="form")
+        self.assertFalse(formset.is_valid())
+        self.assertHTMLEqual(
+            formset.non_form_errors().as_ul(),
+            '<ul class="errorlist nonform"><li>You may only specify a drink once.</li></ul>',
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/formsets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 forms_tests.tests.test_formset_non_form_errors
cat coverage.cover
git checkout 7f33c1e22dbc34a7afae7967783725b10f1f13b1
git apply /root/pre_state.patch
