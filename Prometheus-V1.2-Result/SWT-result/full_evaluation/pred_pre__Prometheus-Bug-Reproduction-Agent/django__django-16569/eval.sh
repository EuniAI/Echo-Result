#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 278881e37619278789942513916acafaa88d26f3 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 278881e37619278789942513916acafaa88d26f3
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/forms_tests/tests/test_formset_add_fields.py b/tests/forms_tests/tests/test_formset_add_fields.py
new file mode 100644
index 0000000000..c8d38f49a2
--- /dev/null
+++ b/tests/forms_tests/tests/test_formset_add_fields.py
@@ -0,0 +1,23 @@
+from django.forms import CharField, Form, formset_factory
+from django.test import SimpleTestCase
+
+
+class MyFieldForm(Form):
+    my_field = CharField()
+
+
+class FormsFormsetTestCase(SimpleTestCase):
+    def test_add_fields_index_none(self):
+        """
+        add_fields() shouldn't fail when index is None, can_delete=True, and
+        can_delete_extra=False.
+        """
+        MyFormSet = formset_factory(
+            form=MyFieldForm,
+            can_delete=True,
+            can_delete_extra=False,
+        )
+        my_formset = MyFormSet(initial=None)
+        # Accessing empty_form shouldn't raise a TypeError.
+        empty_form = my_formset.empty_form
+        self.assertNotIn("DELETE", empty_form.fields)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/formsets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 forms_tests.tests.test_formset_add_fields
cat coverage.cover
git checkout 278881e37619278789942513916acafaa88d26f3
git apply /root/pre_state.patch
