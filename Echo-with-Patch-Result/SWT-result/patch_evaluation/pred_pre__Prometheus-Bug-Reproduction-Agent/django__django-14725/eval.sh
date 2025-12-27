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
diff --git a/tests/test_modelformset_edit_only.py b/tests/test_modelformset_edit_only.py
new file mode 100644
index 0000000000..ba76d44cdb
--- /dev/null
+++ b/tests/test_modelformset_edit_only.py
@@ -0,0 +1,35 @@
+from django.forms.models import modelformset_factory
+from django.test import TestCase
+
+from .models import Author
+
+
+class EditOnlyModelFormsetTest(TestCase):
+    def test_edit_only_formset_with_initial_data(self):
+        """
+        A model formset with max_num=0, validate_max=True, and
+        can_delete=False should be valid if it only contains initial forms.
+        """
+        author = Author.objects.create(name='Charles Baudelaire')
+        AuthorFormSet = modelformset_factory(
+            Author,
+            fields='__all__',
+            max_num=0,
+            validate_max=True,
+            extra=0,
+            can_delete=False,
+        )
+        # POST data for only the existing author.
+        data = {
+            'form-TOTAL_FORMS': '1',
+            'form-INITIAL_FORMS': '1',
+            'form-0-id': str(author.pk),
+            'form-0-name': 'Charles Baudelaire (edited)',
+        }
+        formset = AuthorFormSet(data=data, queryset=Author.objects.all())
+
+        # Before the fix, this fails with an AssertionError because total
+        # forms (1) > max_num (0). After the fix, this passes because new
+        # forms (0) <= max_num (0). can_delete=False is used to avoid an
+        # infinite recursion that would otherwise cause a timeout.
+        self.assertTrue(formset.is_valid())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_modelformset_edit_only
cat coverage.cover
git checkout 0af9a5fc7d765aa05ea784e2c3237675f3bb4b49
git apply /root/pre_state.patch
