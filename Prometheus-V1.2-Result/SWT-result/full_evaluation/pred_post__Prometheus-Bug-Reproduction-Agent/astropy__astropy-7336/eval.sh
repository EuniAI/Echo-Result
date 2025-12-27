#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 732d89c2940156bdc0e200bb36dc38b5e424bcba >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 732d89c2940156bdc0e200bb36dc38b5e424bcba
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/units/decorators.py b/astropy/units/decorators.py
--- a/astropy/units/decorators.py
+++ b/astropy/units/decorators.py
@@ -220,7 +220,7 @@ def wrapper(*func_args, **func_kwargs):
             # Call the original function with any equivalencies in force.
             with add_enabled_equivalencies(self.equivalencies):
                 return_ = wrapped_function(*func_args, **func_kwargs)
-            if wrapped_signature.return_annotation is not inspect.Signature.empty:
+            if wrapped_signature.return_annotation not in (inspect.Signature.empty, None):
                 return return_.to(wrapped_signature.return_annotation)
             else:
                 return return_

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/units/tests/test_regression.py b/astropy/units/tests/test_regression.py
new file mode 100644
index 0000000000..fec2348ec1
--- /dev/null
+++ b/astropy/units/tests/test_regression.py
@@ -0,0 +1,53 @@
+# -*- coding: utf-8 -*-
+# Licensed under a 3-clause BSD style license - see LICENSE.rst
+
+from functools import wraps
+from textwrap import dedent
+
+import pytest
+
+from ... import units as u
+
+
+def py3only(func):
+    """
+    A decorator to run tests that are only valid in Python 3.
+    It works by compiling and executing the source code returned by the test function.
+    """
+    @wraps(func)
+    def wrapper(*args, **kwargs):
+        src = func(*args, **kwargs)
+        code = compile(dedent(src), __file__, 'exec')
+        # This uses an unqualified exec statement illegally in Python 2,
+        # but perfectly allowed in Python 3 so in fact we eval the exec
+        # call. The exec'd code will have access to the scope of this
+        # wrapper, which includes the imported 'u' and 'pytest'.
+        eval('exec(code, globals(), locals())')
+
+    return wrapper
+
+
+@py3only
+def test_init_with_return_annotation_none():
+    """
+    Tests that the quantity_input decorator does not fail on a constructor
+    (`__init__`) that has a return type annotation of `None`.
+
+    This test reproduces the bug reported in issue #7077, where the
+    decorator attempts to perform a unit conversion on the `None` return
+    value of the constructor, leading to an `AttributeError`.
+    """
+    src = '''
+class PoC:
+    @u.quantity_input
+    def __init__(self, voltage: u.V) -> None:
+        self.voltage = voltage
+
+# This instantiation fails when the bug is present.
+poc = PoC(1. * u.V)
+
+# This assertion checks that the __init__ method completed successfully,
+# which will only happen if the bug is fixed.
+assert hasattr(poc, 'voltage')
+'''
+    return src

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/units/decorators\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/units/tests/test_regression.py
cat coverage.cover
git checkout 732d89c2940156bdc0e200bb36dc38b5e424bcba
git apply /root/pre_state.patch
