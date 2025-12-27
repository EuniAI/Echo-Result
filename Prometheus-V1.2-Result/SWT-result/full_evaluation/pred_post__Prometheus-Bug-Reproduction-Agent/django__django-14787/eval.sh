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
diff --git a/tests/decorators/test_method_decorator.py b/tests/decorators/test_method_decorator.py
new file mode 100644
index 0000000000..c497e63952
--- /dev/null
+++ b/tests/decorators/test_method_decorator.py
@@ -0,0 +1,29 @@
+from functools import wraps
+
+from django.test import SimpleTestCase
+from django.utils.decorators import method_decorator
+
+
+class MethodDecoratorTests(SimpleTestCase):
+    def test_decorator_can_access_attributes_of_wrapped_function(self):
+        """
+        A decorator applied via method_decorator() can access the attributes
+        of the function it wraps.
+        """
+        def logger(func):
+            @wraps(func)
+            def inner(*args, **kwargs):
+                # This will raise an AttributeError if `func` is a partial
+                # object without the attributes of the wrapped function.
+                name = func.__name__
+                return func(*args, **kwargs)
+            return inner
+
+        class Test:
+            @method_decorator(logger)
+            def hello_world(self):
+                return "hello"
+
+        # This call fails with an AttributeError before the bug is fixed.
+        # After the fix, it should run without error, and the assertion will pass.
+        self.assertEqual(Test().hello_world(), "hello")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/utils/decorators\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 decorators.test_method_decorator
cat coverage.cover
git checkout 004b4620f6f4ad87261e149898940f2dcd5757ef
git apply /root/pre_state.patch
