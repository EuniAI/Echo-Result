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
diff --git a/django/forms/models.py b/django/forms/models.py
--- a/django/forms/models.py
+++ b/django/forms/models.py
@@ -253,18 +253,11 @@ def __init__(self, options=None):
         self.help_texts = getattr(options, "help_texts", None)
         self.error_messages = getattr(options, "error_messages", None)
         self.field_classes = getattr(options, "field_classes", None)
+        self.formfield_callback = getattr(options, "formfield_callback", None)
 
 
 class ModelFormMetaclass(DeclarativeFieldsMetaclass):
     def __new__(mcs, name, bases, attrs):
-        base_formfield_callback = None
-        for b in bases:
-            if hasattr(b, "Meta") and hasattr(b.Meta, "formfield_callback"):
-                base_formfield_callback = b.Meta.formfield_callback
-                break
-
-        formfield_callback = attrs.pop("formfield_callback", base_formfield_callback)
-
         new_class = super().__new__(mcs, name, bases, attrs)
 
         if bases == (BaseModelForm,):
@@ -308,7 +301,7 @@ def __new__(mcs, name, bases, attrs):
                 opts.fields,
                 opts.exclude,
                 opts.widgets,
-                formfield_callback,
+                opts.formfield_callback,
                 opts.localized_fields,
                 opts.labels,
                 opts.help_texts,
@@ -636,7 +629,7 @@ def modelform_factory(
     class_name = model.__name__ + "Form"
 
     # Class attributes for the new form class.
-    form_class_attrs = {"Meta": Meta, "formfield_callback": formfield_callback}
+    form_class_attrs = {"Meta": Meta}
 
     if getattr(Meta, "fields", None) is None and getattr(Meta, "exclude", None) is None:
         raise ImproperlyConfigured(

EOF_114329324912
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
