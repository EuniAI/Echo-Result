#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0af9a5fc7d765aa05ea784e2c3237675f3bb4b49 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0af9a5fc7d765aa05ea784e2c3237675f3bb4b49
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_formsets/test_disallow_new_object_creation.py b/tests/model_formsets/test_disallow_new_object_creation.py
new file mode 100644
index 0000000000..883f89648f
--- /dev/null
+++ b/tests/model_formsets/test_disallow_new_object_creation.py
@@ -0,0 +1,30 @@
+from django.forms.models import modelformset_factory
+from django.test import TestCase
+
+from .models import Author
+
+
+class ModelFormsetTests(TestCase):
+    def test_modelformset_disallow_new_object_creation(self):
+        """
+        A model formset can be configured to be "edit only" by using
+        extra=0 and validate_max=True. This should prevent new objects from
+        being created when a user adds extra forms via client-side code.
+        """
+        author = Author.objects.create(name='Charles Baudelaire')
+        AuthorFormSet = modelformset_factory(
+            Author, fields=('name',), extra=0, validate_max=True
+        )
+        # This data simulates a user submitting an extra form to add a new
+        # author, which should not be allowed.
+        data = {
+            'form-TOTAL_FORMS': '2',
+            'form-INITIAL_FORMS': '1',
+            'form-MAX_NUM_FORMS': '',
+            'form-0-id': str(author.pk),
+            'form-0-name': 'Charles Baudelaire',
+            'form-1-name': 'Paul Verlaine',
+        }
+        formset = AuthorFormSet(data, queryset=Author.objects.all())
+        self.assertFalse(formset.is_valid())
+        self.assertEqual(formset.non_form_errors(), ['Please submit at most 1 form.'])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_formsets.test_disallow_new_object_creation
cat coverage.cover
git checkout 0af9a5fc7d765aa05ea784e2c3237675f3bb4b49
git apply /root/pre_state.patch
