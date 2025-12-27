#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 88e67a54b7ed0210c11523a337b498aadb2f5187 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 88e67a54b7ed0210c11523a337b498aadb2f5187
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_forms/test_modelform_factory.py b/tests/model_forms/test_modelform_factory.py
new file mode 100644
index 0000000000..5912ab11a9
--- /dev/null
+++ b/tests/model_forms/test_modelform_factory.py
@@ -0,0 +1,63 @@
+from django import forms
+from django.db import models
+from django.forms.models import modelform_factory
+from django.test import SimpleTestCase
+
+
+# Models needed for the test, based on the provided context.
+class Writer(models.Model):
+    name = models.CharField(max_length=50)
+
+    class Meta:
+        app_label = "model_forms"
+
+
+class Category(models.Model):
+    name = models.CharField(max_length=20)
+
+    class Meta:
+        app_label = "model_forms"
+
+
+class Article(models.Model):
+    headline = models.CharField(max_length=50)
+    slug = models.SlugField()
+    pub_date = models.DateField()
+    created = models.DateField(editable=False)
+    writer = models.ForeignKey(Writer, models.CASCADE)
+    article = models.TextField()
+    categories = models.ManyToManyField(Category, blank=True)
+    status = models.PositiveIntegerField(blank=True, null=True)
+
+    class Meta:
+        app_label = "model_forms"
+
+
+class FormfieldCallbackMetaTests(SimpleTestCase):
+    def test_factory_respects_meta_formfield_callback(self):
+        """
+        modelform_factory() should respect the formfield_callback specified in
+        the base form's Meta.
+        """
+
+        def make_fields_required(field, **kwargs):
+            formfield = field.formfield(**kwargs)
+            if formfield:
+                formfield.required = True
+            return formfield
+
+        class ArticleFormWithCallback(forms.ModelForm):
+            class Meta:
+                model = Article
+                fields = ["status"]
+                formfield_callback = make_fields_required
+
+        # The bug is that modelform_factory ignores the formfield_callback
+        # from ArticleFormWithCallback.Meta.
+        FactoryForm = modelform_factory(Article, form=ArticleFormWithCallback)
+        form = FactoryForm()
+
+        # The 'status' field is not required on the model (blank=True), but
+        # the callback should make it required. This assertion will fail if
+        # the bug is present.
+        self.assertTrue(form.fields["status"].required)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_forms.test_modelform_factory
cat coverage.cover
git checkout 88e67a54b7ed0210c11523a337b498aadb2f5187
git apply /root/pre_state.patch
