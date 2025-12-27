#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fe886eee36be8022f34cfe59aa61ff1c21fe01d9 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fe886eee36be8022f34cfe59aa61ff1c21fe01d9
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/utils/functional.py b/django/utils/functional.py
--- a/django/utils/functional.py
+++ b/django/utils/functional.py
@@ -176,6 +176,12 @@ def __mod__(self, rhs):
                 return str(self) % rhs
             return self.__cast() % rhs
 
+        def __add__(self, other):
+            return self.__cast() + other
+
+        def __radd__(self, other):
+            return other + self.__cast()
+
         def __deepcopy__(self, memo):
             # Instances of this class are effectively immutable. It's just a
             # collection of functions. So we don't need to do anything

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/filter_tests/test_add_regressions.py b/tests/template_tests/filter_tests/test_add_regressions.py
new file mode 100644
index 0000000000..1a53edb20e
--- /dev/null
+++ b/tests/template_tests/filter_tests/test_add_regressions.py
@@ -0,0 +1,73 @@
+from datetime import date, timedelta
+
+from django.template.defaultfilters import add
+from django.test import SimpleTestCase
+from django.utils.translation import gettext_lazy
+
+from ..utils import setup
+
+
+class AddTests(SimpleTestCase):
+    """
+    Tests for #11687 and #16676
+    """
+
+    @setup({'add01': '{{ i|add:"5" }}'})
+    def test_add01(self):
+        output = self.engine.render_to_string('add01', {'i': 2000})
+        self.assertEqual(output, '2005')
+
+    @setup({'add02': '{{ i|add:"napis" }}'})
+    def test_add02(self):
+        output = self.engine.render_to_string('add02', {'i': 2000})
+        self.assertEqual(output, '')
+
+    @setup({'add03': '{{ i|add:16 }}'})
+    def test_add03(self):
+        output = self.engine.render_to_string('add03', {'i': 'not_an_int'})
+        self.assertEqual(output, '')
+
+    @setup({'add04': '{{ i|add:"16" }}'})
+    def test_add04(self):
+        output = self.engine.render_to_string('add04', {'i': 'not_an_int'})
+        self.assertEqual(output, 'not_an_int16')
+
+    @setup({'add05': '{{ l1|add:l2 }}'})
+    def test_add05(self):
+        output = self.engine.render_to_string('add05', {'l1': [1, 2], 'l2': [3, 4]})
+        self.assertEqual(output, '[1, 2, 3, 4]')
+
+    @setup({'add06': '{{ t1|add:t2 }}'})
+    def test_add06(self):
+        output = self.engine.render_to_string('add06', {'t1': (3, 4), 't2': (1, 2)})
+        self.assertEqual(output, '(3, 4, 1, 2)')
+
+    @setup({'add07': '{{ d|add:t }}'})
+    def test_add07(self):
+        output = self.engine.render_to_string('add07', {
+            'd': date(2008, 11, 20),
+            't': timedelta(days=1),
+        })
+        self.assertEqual(output, 'Nov. 21, 2008')
+
+    @setup({'add_lazy_string': '{{ a|add:b }}'})
+    def test_add_lazy_string(self):
+        """
+        The add filter should work when adding a string to a lazy string.
+        """
+        output = self.engine.render_to_string(
+            'add_lazy_string',
+            {'a': 'regular', 'b': gettext_lazy('lazy')}
+        )
+        self.assertEqual(output, 'regularlazy')
+
+    @setup({'add_lazy_string_rev': '{{ a|add:b }}'})
+    def test_add_lazy_string_reversed(self):
+        """
+        The add filter should work when adding a lazy string to a string.
+        """
+        output = self.engine.render_to_string(
+            'add_lazy_string_rev',
+            {'a': gettext_lazy('lazy'), 'b': 'regular'}
+        )
+        self.assertEqual(output, 'lazyregular')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/functional\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.filter_tests.test_add_regressions
cat coverage.cover
git checkout fe886eee36be8022f34cfe59aa61ff1c21fe01d9
git apply /root/pre_state.patch
