#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 910ecd1b8df7678f45c3d507dde6bcb1faafa243 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 910ecd1b8df7678f45c3d507dde6bcb1faafa243
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_boundwidget_id_for_label.py b/tests/test_boundwidget_id_for_label.py
new file mode 100644
index 0000000000..2730cf35e1
--- /dev/null
+++ b/tests/test_boundwidget_id_for_label.py
@@ -0,0 +1,21 @@
+from django.forms import (
+    CheckboxSelectMultiple, Form, MultipleChoiceField
+)
+from django.test import SimpleTestCase
+
+
+class BoundWidgetIdForLabelTest(SimpleTestCase):
+    def test_boundwidget_id_for_label_custom_auto_id(self):
+        """
+        BoundWidget.id_for_label() should use the widget's generated ID
+        when the form has a custom auto_id.
+        """
+        class MyForm(Form):
+            field = MultipleChoiceField(
+                choices=[('a', 'A'), ('b', 'B')],
+                widget=CheckboxSelectMultiple,
+            )
+
+        form = MyForm(auto_id='my_id_%s')
+        bound_widget = form['field'][0]
+        self.assertEqual(bound_widget.id_for_label, 'my_id_field_0')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/boundfield\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_boundwidget_id_for_label
cat coverage.cover
git checkout 910ecd1b8df7678f45c3d507dde6bcb1faafa243
git apply /root/pre_state.patch
