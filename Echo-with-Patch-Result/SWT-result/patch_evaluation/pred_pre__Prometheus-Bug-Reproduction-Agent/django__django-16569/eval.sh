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
diff --git a/tests/test_formset_add_fields.py b/tests/test_formset_add_fields.py
new file mode 100644
index 0000000000..b6f15be3cc
--- /dev/null
+++ b/tests/test_formset_add_fields.py
@@ -0,0 +1,24 @@
+from django.forms import CharField, Form, formset_factory
+from django.test import SimpleTestCase
+
+
+class MyForm(Form):
+    my_field = CharField()
+
+
+class FormsetAddFieldsTest(SimpleTestCase):
+    def test_add_fields_index_none(self):
+        """
+        add_fields() shouldn't fail when index is None, can_delete=True, and
+        can_delete_extra=False.
+        """
+        MyFormSet = formset_factory(
+            MyForm,
+            can_delete=True,
+            can_delete_extra=False,
+        )
+        formset = MyFormSet(initial=None)
+        # Accessing empty_form calls add_fields() with index=None, which
+        # raises a TypeError on the unpatched code. This unhandled exception
+        # will cause the test to fail, as required.
+        formset.empty_form

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/formsets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_formset_add_fields
cat coverage.cover
git checkout 278881e37619278789942513916acafaa88d26f3
git apply /root/pre_state.patch
