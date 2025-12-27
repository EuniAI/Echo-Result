#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e6588aa4e793b7f56f4cadbfa155b581e0efc59a >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e6588aa4e793b7f56f4cadbfa155b581e0efc59a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/forms/models.py b/django/forms/models.py
--- a/django/forms/models.py
+++ b/django/forms/models.py
@@ -83,7 +83,7 @@ def model_to_dict(instance, fields=None, exclude=None):
     for f in chain(opts.concrete_fields, opts.private_fields, opts.many_to_many):
         if not getattr(f, 'editable', False):
             continue
-        if fields and f.name not in fields:
+        if fields is not None and f.name not in fields:
             continue
         if exclude and f.name in exclude:
             continue

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_model_to_dict_empty_fields.py b/tests/test_model_to_dict_empty_fields.py
new file mode 100644
index 0000000000..1df1af8eb6
--- /dev/null
+++ b/tests/test_model_to_dict_empty_fields.py
@@ -0,0 +1,28 @@
+from django.db import models
+from django.forms.models import model_to_dict
+from django.test import TestCase
+
+
+# Define the model directly in the test file to make it self-contained.
+class Person(models.Model):
+    name = models.CharField(max_length=100)
+
+    class Meta:
+        # app_label is necessary for models defined outside of an app's models.py
+        app_label = 'model_forms'
+
+
+class ModelToDictEmptyFieldsTests(TestCase):
+
+    def test_model_to_dict_empty_fields(self):
+        """
+        model_to_dict() should return an empty dict for an empty list of
+        fields, but it returns all fields.
+        """
+        # Create an instance of the model. It doesn't need to be saved.
+        instance = Person(name='test')
+        # Call model_to_dict with an empty list for the 'fields' argument.
+        data = model_to_dict(instance, fields=[])
+        # This assertion will fail with the buggy code because `data` will not
+        # be empty. It will pass once the bug is fixed.
+        self.assertEqual(data, {})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_model_to_dict_empty_fields
cat coverage.cover
git checkout e6588aa4e793b7f56f4cadbfa155b581e0efc59a
git apply /root/pre_state.patch
