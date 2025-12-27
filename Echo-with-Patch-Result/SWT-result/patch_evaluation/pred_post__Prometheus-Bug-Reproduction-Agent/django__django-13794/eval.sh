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
diff --git a/tests/test_add_lazy_string.py b/tests/test_add_lazy_string.py
new file mode 100644
index 0000000000..a2a5aadb73
--- /dev/null
+++ b/tests/test_add_lazy_string.py
@@ -0,0 +1,22 @@
+from django.template import Context, Engine
+from django.test import SimpleTestCase
+from django.utils.functional import lazystr
+
+
+class AddLazyStringTest(SimpleTestCase):
+
+    def test_add_lazy_string(self):
+        """
+        The add filter should handle concatenation with lazy strings.
+        """
+        template = Engine().from_string('{{ val1|add:val2 }}')
+        context = Context({'val1': 'lazy', 'val2': lazystr(' string')})
+        self.assertEqual(template.render(context), 'lazy string')
+
+    def test_add_lazy_string_reverse(self):
+        """
+        The add filter should handle concatenation with lazy strings.
+        """
+        template = Engine().from_string('{{ val1|add:val2 }}')
+        context = Context({'val1': lazystr('lazy'), 'val2': ' string'})
+        self.assertEqual(template.render(context), 'lazy string')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/functional\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_add_lazy_string
cat coverage.cover
git checkout fe886eee36be8022f34cfe59aa61ff1c21fe01d9
git apply /root/pre_state.patch
