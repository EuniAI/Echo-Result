#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 53d8646f799de7f92ab9defe9dc56c6125448102 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 53d8646f799de7f92ab9defe9dc56c6125448102
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/forms/widgets.py b/django/forms/widgets.py
--- a/django/forms/widgets.py
+++ b/django/forms/widgets.py
@@ -387,6 +387,9 @@ def value_from_datadict(self, data, files, name):
     def value_omitted_from_data(self, data, files, name):
         return name not in files
 
+    def use_required_attribute(self, initial):
+        return super().use_required_attribute(initial) and not initial
+
 
 FILE_INPUT_CONTRADICTION = object()
 
@@ -451,9 +454,6 @@ def value_from_datadict(self, data, files, name):
             return False
         return upload
 
-    def use_required_attribute(self, initial):
-        return super().use_required_attribute(initial) and not initial
-
     def value_omitted_from_data(self, data, files, name):
         return (
             super().value_omitted_from_data(data, files, name) and

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/forms_tests/widget_tests/test_fileinput_use_required_attribute.py b/tests/forms_tests/widget_tests/test_fileinput_use_required_attribute.py
new file mode 100644
index 0000000000..1056db4c9a
--- /dev/null
+++ b/tests/forms_tests/widget_tests/test_fileinput_use_required_attribute.py
@@ -0,0 +1,43 @@
+from django.forms import FileInput
+from django.forms.renderers import DjangoTemplates, Jinja2
+from django.test import SimpleTestCase
+
+try:
+    import jinja2
+except ImportError:
+    jinja2 = None
+
+
+class WidgetTest(SimpleTestCase):
+    beatles = (('J', 'John'), ('P', 'Paul'), ('G', 'George'), ('R', 'Ringo'))
+
+    @classmethod
+    def setUpClass(cls):
+        cls.django_renderer = DjangoTemplates()
+        cls.jinja2_renderer = Jinja2() if jinja2 else None
+        cls.renderers = [cls.django_renderer] + ([cls.jinja2_renderer] if cls.jinja2_renderer else [])
+        super().setUpClass()
+
+    def check_html(self, widget, name, value, html='', attrs=None, strict=False, **kwargs):
+        assertEqual = self.assertEqual if strict else self.assertHTMLEqual
+        if self.jinja2_renderer:
+            output = widget.render(name, value, attrs=attrs, renderer=self.jinja2_renderer, **kwargs)
+            # Django escapes quotes with '&quot;' while Jinja2 uses '&#34;'.
+            output = output.replace('&#34;', '&quot;')
+            # Django escapes single quotes with '&#x27;' while Jinja2 uses '&#39;'.
+            output = output.replace('&#39;', '&#x27;')
+            assertEqual(output, html)
+
+        output = widget.render(name, value, attrs=attrs, renderer=self.django_renderer, **kwargs)
+        assertEqual(output, html)
+
+
+class FileInputTest(WidgetTest):
+    widget = FileInput()
+
+    def test_use_required_attribute_with_initial(self):
+        """
+        FileInput.use_required_attribute() should be False when initial data
+        exists because the user may want to keep the existing file.
+        """
+        self.assertIs(self.widget.use_required_attribute('resume.txt'), False)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/widgets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 forms_tests.widget_tests.test_fileinput_use_required_attribute
cat coverage.cover
git checkout 53d8646f799de7f92ab9defe9dc56c6125448102
git apply /root/pre_state.patch
