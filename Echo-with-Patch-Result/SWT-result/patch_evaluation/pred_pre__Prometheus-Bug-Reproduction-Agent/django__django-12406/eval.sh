#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 335c9c94acf263901fb023404408880245b0c4b4 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 335c9c94acf263901fb023404408880245b0c4b4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_foreignkey_radioselect.py b/tests/test_foreignkey_radioselect.py
new file mode 100644
index 0000000000..1651b3ce55
--- /dev/null
+++ b/tests/test_foreignkey_radioselect.py
@@ -0,0 +1,32 @@
+from django import forms
+from django.db import models
+from django.forms.widgets import RadioSelect
+from django.test import TestCase
+
+from .models import BatchData, TestRun
+
+
+class TestRunForm(forms.ModelForm):
+    class Meta:
+        model = TestRun
+        fields = ['data_file']
+        widgets = {
+            'data_file': RadioSelect(),
+        }
+
+
+class ForeignKeyRadioSelectTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        BatchData.objects.create(name='First Data File')
+
+    def test_radioselect_on_required_fk_no_blank_choice(self):
+        """
+        A ModelForm with a RadioSelect on a required ForeignKey should not
+        render a blank choice.
+        """
+        form = TestRunForm()
+        field = form.fields['data_file']
+        # The fix ensures empty_label is None for required ModelChoiceFields
+        # that use a radio widget.
+        self.assertIsNone(field.empty_label)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py|django/db/models/fields/related\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_foreignkey_radioselect
cat coverage.cover
git checkout 335c9c94acf263901fb023404408880245b0c4b4
git apply /root/pre_state.patch
