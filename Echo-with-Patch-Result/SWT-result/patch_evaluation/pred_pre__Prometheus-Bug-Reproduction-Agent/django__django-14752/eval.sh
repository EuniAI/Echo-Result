#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD b64db05b9cedd96905d637a2d824cbbf428e40e7 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff b64db05b9cedd96905d637a2d824cbbf428e40e7
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_views/test_autocomplete_refactor.py b/tests/admin_views/test_autocomplete_refactor.py
new file mode 100644
index 0000000000..4dcbb450cf
--- /dev/null
+++ b/tests/admin_views/test_autocomplete_refactor.py
@@ -0,0 +1,59 @@
+from django.contrib.admin.views.autocomplete import AutocompleteJsonView
+from django.test import TestCase
+
+# Import the existing Question model from the test application's models.
+# This relies on the test file being placed in the 'tests/admin_views/' directory
+# by the test runner, which is standard practice and avoids model conflicts.
+from .models import Question
+
+
+class CustomAutocompleteJsonView(AutocompleteJsonView):
+    """
+    A custom AutocompleteJsonView that overrides serialize_result to add
+    extra data, as proposed in the issue description.
+    """
+
+    def serialize_result(self, obj, to_field_name):
+        """
+        This override calls super() to extend the base result. This call will
+        raise an AttributeError before the patch is applied, because the
+        method does not exist on the base class.
+        """
+        data = super().serialize_result(obj, to_field_name)
+        data["notes"] = obj.question
+        return data
+
+
+class AutocompleteRefactorTest(TestCase):
+    """
+    Tests the refactoring of AutocompleteJsonView to allow customization of the
+    result serialization.
+    """
+
+    @classmethod
+    def setUpTestData(cls):
+        # Create a single model instance to be used in the test.
+        cls.question = Question.objects.create(question="Is this a test?")
+
+    def test_serialize_result_can_be_extended(self):
+        """
+        Tests that overriding serialize_result works as an extension point.
+        This test directly calls the method to isolate the unit of behavior.
+        """
+        view = CustomAutocompleteJsonView()
+        obj = self.question
+        to_field_name = "pk"
+
+        # This line will raise an AttributeError before the patch because
+        # AutocompleteJsonView has no 'serialize_result' method for super()
+        # to call. This is the expected failure.
+        result = view.serialize_result(obj, to_field_name)
+
+        # This assertion will only be reached after the patch is applied.
+        # It verifies that the super() call worked and the extra data was added.
+        expected_result = {
+            "id": str(obj.pk),
+            "text": str(obj),
+            "notes": obj.question,
+        }
+        self.assertEqual(result, expected_result)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/views/autocomplete\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_views.test_autocomplete_refactor
cat coverage.cover
git checkout b64db05b9cedd96905d637a2d824cbbf428e40e7
git apply /root/pre_state.patch
