#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 93cedc82f29076c824d476354527af1150888e4f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 93cedc82f29076c824d476354527af1150888e4f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/manager.py b/django/db/models/manager.py
--- a/django/db/models/manager.py
+++ b/django/db/models/manager.py
@@ -1,5 +1,6 @@
 import copy
 import inspect
+from functools import wraps
 from importlib import import_module
 
 from django.db import router
@@ -81,11 +82,10 @@ def check(self, **kwargs):
     @classmethod
     def _get_queryset_methods(cls, queryset_class):
         def create_method(name, method):
+            @wraps(method)
             def manager_method(self, *args, **kwargs):
                 return getattr(self.get_queryset(), name)(*args, **kwargs)
 
-            manager_method.__name__ = method.__name__
-            manager_method.__doc__ = method.__doc__
             return manager_method
 
         new_methods = {}

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_manager_signature.py b/tests/test_manager_signature.py
new file mode 100644
index 0000000000..1da4d4227b
--- /dev/null
+++ b/tests/test_manager_signature.py
@@ -0,0 +1,34 @@
+import inspect
+
+from django.db import models
+from django.db.models.query import QuerySet
+from django.test import TestCase
+
+
+class Person(models.Model):
+    name = models.CharField(max_length=100)
+
+    class Meta:
+        app_label = "manager_signature"
+
+
+class ManagerSignatureTests(TestCase):
+    def test_manager_method_signature(self):
+        """
+        inspect.signature() should return the correct signature for manager
+        methods that are proxied from QuerySet.
+        """
+        # On the buggy version, this is (*args, **kwargs).
+        manager_sig = inspect.signature(Person.objects.bulk_create)
+
+        # The signature from the source QuerySet method is the source of truth.
+        queryset_sig = inspect.signature(QuerySet.bulk_create)
+
+        # The expected signature on the manager is the same as the queryset
+        # method, but without the 'self' parameter, as inspect.signature() on
+        # a bound method omits it.
+        expected_params = list(queryset_sig.parameters.values())[1:]
+        expected_sig = inspect.Signature(parameters=expected_params)
+
+        # This will fail on the old code and pass on the new code.
+        self.assertEqual(manager_sig, expected_sig)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/manager\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_manager_signature
cat coverage.cover
git checkout 93cedc82f29076c824d476354527af1150888e4f
git apply /root/pre_state.patch
