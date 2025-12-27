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
diff --git a/tests/model_forms/test_model_to_dict.py b/tests/model_forms/test_model_to_dict.py
new file mode 100644
index 0000000000..50118386be
--- /dev/null
+++ b/tests/model_forms/test_model_to_dict.py
@@ -0,0 +1,26 @@
+import datetime
+from django.test import TestCase
+from django.forms.models import model_to_dict
+from .models import Colour, ColourfulItem, Writer
+
+
+class ModelToDictTests(TestCase):
+    def test_many_to_many(self):
+        """Data for a ManyToManyField is a list rather than a lazy QuerySet."""
+        blue = Colour.objects.create(name='blue')
+        red = Colour.objects.create(name='red')
+        item = ColourfulItem.objects.create()
+        item.colours.set([blue])
+        data = model_to_dict(item)['colours']
+        self.assertEqual(data, [blue])
+        item.colours.set([red])
+        # If data were a QuerySet, it would be reevaluated here and give "red"
+        # instead of the original value.
+        self.assertEqual(data, [blue])
+
+    def test_model_to_dict_empty_fields(self):
+        """
+        model_to_dict() with an empty fields list should return an empty dict.
+        """
+        writer = Writer.objects.create(name='Test Writer')
+        self.assertEqual(model_to_dict(writer, fields=[]), {})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_forms.test_model_to_dict
cat coverage.cover
git checkout e6588aa4e793b7f56f4cadbfa155b581e0efc59a
git apply /root/pre_state.patch
