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
diff --git a/tests/test_formset_non_form_errors.py b/tests/test_formset_non_form_errors.py
new file mode 100644
index 0000000000..4a411be35a
--- /dev/null
+++ b/tests/test_formset_non_form_errors.py
@@ -0,0 +1,32 @@
+from django.core.exceptions import ValidationError
+from django.forms import CharField, Form
+from django.forms.formsets import formset_factory
+from django.test import SimpleTestCase
+
+
+class ArticleForm(Form):
+    title = CharField(required=False)
+
+
+class FormsetNonFormErrorsTest(SimpleTestCase):
+    def test_non_form_errors_have_nonform_class_with_validate_min(self):
+        """
+        Non-form errors from built-in validation (like validate_min) should
+        be rendered with a 'nonform' CSS class.
+        """
+        ArticleFormSet = formset_factory(ArticleForm, min_num=1, validate_min=True)
+        # Submit data with 0 completed forms, which will trigger the min_num
+        # validation error.
+        data = {
+            'form-TOTAL_FORMS': '1',
+            'form-INITIAL_FORMS': '0',
+            'form-0-title': '',
+        }
+        formset = ArticleFormSet(data, prefix='form')
+        self.assertFalse(formset.is_valid())
+        # This assertion checks that the non-form error list has the 'nonform' class.
+        # It will fail before the patch and pass after.
+        self.assertHTMLEqual(
+            formset.non_form_errors().as_ul(),
+            '<ul class="errorlist nonform"><li>Please submit at least 1 form.</li></ul>'
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/formsets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_formset_non_form_errors
cat coverage.cover
git checkout 7f33c1e22dbc34a7afae7967783725b10f1f13b1
git apply /root/pre_state.patch
