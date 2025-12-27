#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 004b4620f6f4ad87261e149898940f2dcd5757ef >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 004b4620f6f4ad87261e149898940f2dcd5757ef
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/utils/decorators.py b/django/utils/decorators.py
--- a/django/utils/decorators.py
+++ b/django/utils/decorators.py
@@ -37,7 +37,7 @@ def _wrapper(self, *args, **kwargs):
         # 'self' argument, but it's a closure over self so it can call
         # 'func'. Also, wrap method.__get__() in a function because new
         # attributes can't be set on bound method objects, only on functions.
-        bound_method = partial(method.__get__(self, type(self)))
+        bound_method = wraps(method)(partial(method.__get__(self, type(self))))
         for dec in decorators:
             bound_method = dec(bound_method)
         return bound_method(*args, **kwargs)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_method_decorator.py b/tests/test_method_decorator.py
new file mode 100644
index 0000000000..44cdecc515
--- /dev/null
+++ b/tests/test_method_decorator.py
@@ -0,0 +1,28 @@
+from functools import wraps
+
+from django.test import SimpleTestCase
+from django.utils.decorators import method_decorator
+
+
+class MethodDecoratorWrapperAssignmentTests(SimpleTestCase):
+    def test_wrapper_assignments(self):
+        """
+        method_decorator() should preserve wrapper assignments, allowing
+        decorators to access properties like __name__.
+        """
+
+        def decorator(func):
+            @wraps(func)
+            def inner(*args, **kwargs):
+                # Before the fix, `func` is a partial object which has no
+                # __name__ attribute, causing an AttributeError.
+                return func.__name__
+
+            return inner
+
+        class Test:
+            @method_decorator(decorator)
+            def method(self):
+                pass
+
+        self.assertEqual(Test().method(), "method")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/decorators\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_method_decorator
cat coverage.cover
git checkout 004b4620f6f4ad87261e149898940f2dcd5757ef
git apply /root/pre_state.patch
