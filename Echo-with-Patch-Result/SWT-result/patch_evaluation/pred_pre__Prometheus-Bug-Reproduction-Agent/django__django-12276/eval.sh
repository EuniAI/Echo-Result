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
diff --git a/tests/forms_tests/widget_tests/test_fileinput_use_required_attribute.py b/tests/forms_tests/widget_tests/test_fileinput_use_required_attribute.py
new file mode 100644
index 0000000000..985ab3bc55
--- /dev/null
+++ b/tests/forms_tests/widget_tests/test_fileinput_use_required_attribute.py
@@ -0,0 +1,29 @@
+from django.forms import FileInput
+
+from .base import WidgetTest
+
+
+class FileInputTest(WidgetTest):
+    widget = FileInput()
+
+    def test_render(self):
+        """
+        FileInput widgets never render the value attribute. The old value
+        isn't useful if a form is updated or an error occurred.
+        """
+        self.check_html(self.widget, 'email', 'test@example.com', html='<input type="file" name="email">')
+        self.check_html(self.widget, 'email', '', html='<input type="file" name="email">')
+        self.check_html(self.widget, 'email', None, html='<input type="file" name="email">')
+
+    def test_value_omitted_from_data(self):
+        self.assertIs(self.widget.value_omitted_from_data({}, {}, 'field'), True)
+        self.assertIs(self.widget.value_omitted_from_data({}, {'field': 'value'}, 'field'), False)
+
+    def test_use_required_attribute(self):
+        """
+        FileInput.use_required_attribute() should be False when an initial
+        value is present.
+        """
+        # An initial value means a file is already uploaded, so the user
+        # shouldn't be required to upload another.
+        self.assertIs(self.widget.use_required_attribute('some-file.txt'), False)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/widgets\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 forms_tests.widget_tests.test_fileinput_use_required_attribute
cat coverage.cover
git checkout 53d8646f799de7f92ab9defe9dc56c6125448102
git apply /root/pre_state.patch
