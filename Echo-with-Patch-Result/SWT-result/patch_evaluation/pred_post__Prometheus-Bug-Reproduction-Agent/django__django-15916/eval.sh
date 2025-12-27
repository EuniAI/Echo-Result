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
diff --git a/tests/model_forms/test_formfield_callback.py b/tests/model_forms/test_formfield_callback.py
new file mode 100644
index 0000000000..074068a53e
--- /dev/null
+++ b/tests/model_forms/test_formfield_callback.py
@@ -0,0 +1,131 @@
+from django import forms
+from django.core.exceptions import ImproperlyConfigured
+from django.db import models
+from django.forms.models import modelform_factory
+from django.test import SimpleTestCase
+
+from .models import Person, Post
+
+
+def all_required(field, **kwargs):
+    """A callback that makes every form field required."""
+    formfield = field.formfield(**kwargs)
+    if formfield:
+        formfield.required = True
+    return formfield
+
+
+class FormFieldCallbackTests(SimpleTestCase):
+    def test_baseform_with_widgets_in_meta(self):
+        """
+        Using base forms with widgets defined in Meta should not raise errors.
+        """
+        widget = forms.Textarea()
+
+        class BaseForm(forms.ModelForm):
+            class Meta:
+                model = Person
+                widgets = {"name": widget}
+                fields = "__all__"
+
+        Form = modelform_factory(Person, form=BaseForm)
+        self.assertIsInstance(Form.base_fields["name"].widget, forms.Textarea)
+
+    def test_factory_with_widget_argument(self):
+        """Regression for #15315: modelform_factory should accept widgets
+        argument
+        """
+        widget = forms.Textarea()
+
+        # Without a widget should not set the widget to textarea
+        Form = modelform_factory(Person, fields="__all__")
+        self.assertNotEqual(Form.base_fields["name"].widget.__class__, forms.Textarea)
+
+        # With a widget should not set the widget to textarea
+        Form = modelform_factory(Person, fields="__all__", widgets={"name": widget})
+        self.assertEqual(Form.base_fields["name"].widget.__class__, forms.Textarea)
+
+    def test_modelform_factory_without_fields(self):
+        """Regression for #19733"""
+        message = (
+            "Calling modelform_factory without defining 'fields' or 'exclude' "
+            "explicitly is prohibited."
+        )
+        with self.assertRaisesMessage(ImproperlyConfigured, message):
+            modelform_factory(Person)
+
+    def test_modelform_factory_with_all_fields(self):
+        """Regression for #19733"""
+        form = modelform_factory(Person, fields="__all__")
+        self.assertEqual(list(form.base_fields), ["name"])
+
+    def test_custom_callback(self):
+        """A custom formfield_callback is used if provided"""
+        callback_args = []
+
+        def callback(db_field, **kwargs):
+            callback_args.append((db_field, kwargs))
+            return db_field.formfield(**kwargs)
+
+        widget = forms.Textarea()
+
+        class BaseForm(forms.ModelForm):
+            class Meta:
+                model = Person
+                widgets = {"name": widget}
+                fields = "__all__"
+
+        modelform_factory(Person, form=BaseForm, formfield_callback=callback)
+        id_field, name_field = Person._meta.fields
+
+        self.assertEqual(
+            callback_args, [(id_field, {}), (name_field, {"widget": widget})]
+        )
+
+    def test_bad_callback(self):
+        # A bad callback provided by user still gives an error
+        with self.assertRaises(TypeError):
+            modelform_factory(
+                Person,
+                fields="__all__",
+                formfield_callback="not a function or callable",
+            )
+
+    def test_inherit_after_custom_callback(self):
+        def callback(db_field, **kwargs):
+            if isinstance(db_field, models.CharField):
+                return forms.CharField(widget=forms.Textarea)
+            return db_field.formfield(**kwargs)
+
+        class BaseForm(forms.ModelForm):
+            class Meta:
+                model = Person
+                fields = "__all__"
+
+        NewForm = modelform_factory(Person, form=BaseForm, formfield_callback=callback)
+
+        class InheritedForm(NewForm):
+            pass
+
+        for name in NewForm.base_fields:
+            self.assertEqual(
+                type(InheritedForm.base_fields[name].widget),
+                type(NewForm.base_fields[name].widget),
+            )
+
+    def test_factory_inherits_formfield_callback_from_meta(self):
+        """
+        modelform_factory() should inherit formfield_callback from the base
+        form's Meta.
+        """
+
+        class PostForm(forms.ModelForm):
+            class Meta:
+                model = Post
+                fields = ["title", "posted"]
+                formfield_callback = all_required
+
+        FactoryForm = modelform_factory(Post, form=PostForm)
+        # Post.title is blank=True, so the form field is not required by
+        # default. The callback should make it required.
+        self.assertTrue(FactoryForm.base_fields["title"].required)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_forms.test_formfield_callback
cat coverage.cover
git checkout 88e67a54b7ed0210c11523a337b498aadb2f5187
git apply /root/pre_state.patch
