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
diff --git a/tests/model_forms/test_modelchoicefield_validation.py b/tests/model_forms/test_modelchoicefield_validation.py
new file mode 100644
index 0000000000..3e148158ba
--- /dev/null
+++ b/tests/model_forms/test_modelchoicefield_validation.py
@@ -0,0 +1,43 @@
+from django import forms
+from django.core.exceptions import ValidationError
+from django.test import TestCase
+
+# Import the existing Category model from the app's models file instead of
+# redefining it. This resolves the database setup conflict.
+from .models import Category
+
+
+class ModelChoiceFieldInvalidValueMessageTest(TestCase):
+    @classmethod
+    def setUpTestData(cls):
+        """
+        Create test data using the existing Category model. This setup will
+        now succeed as the database table `model_forms_category` can be
+        created without conflicts.
+        """
+        Category.objects.create(
+            name="Entertainment", slug="entertainment", url="entertainment"
+        )
+        Category.objects.create(name="A test", slug="test", url="test")
+
+    def test_invalid_choice_message_includes_value(self):
+        """
+        Tests that ModelChoiceField's ValidationError for an invalid choice
+        includes the invalid value in its message, making it consistent with
+        ChoiceField.
+        """
+        # Initialize the field with the queryset of existing categories.
+        field = forms.ModelChoiceField(queryset=Category.objects.all())
+        invalid_pk = 999
+
+        # This is the core of the test. The expected message includes the
+        # invalid value (`%(value)s`). The current implementation does not
+        # provide the value, so this assertion will fail. When the bug is
+        # fixed, the assertion will pass.
+        expected_message = (
+            f"'Select a valid choice. {invalid_pk} is not one of the available choices.'"
+        )
+
+        with self.assertRaisesMessage(ValidationError, expected_message):
+            # Attempt to clean a value that is not a valid choice.
+            field.clean(invalid_pk)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_forms.test_modelchoicefield_validation
cat coverage.cover
git checkout 42e8cf47c7ee2db238bf91197ea398126c546741
git apply /root/pre_state.patch
