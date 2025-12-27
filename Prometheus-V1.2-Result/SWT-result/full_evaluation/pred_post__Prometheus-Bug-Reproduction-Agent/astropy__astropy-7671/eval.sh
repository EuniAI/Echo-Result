#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a7141cd90019b62688d507ae056298507678c058 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a7141cd90019b62688d507ae056298507678c058
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/utils/introspection.py b/astropy/utils/introspection.py
--- a/astropy/utils/introspection.py
+++ b/astropy/utils/introspection.py
@@ -4,6 +4,7 @@
 
 
 import inspect
+import re
 import types
 import importlib
 from distutils.version import LooseVersion
@@ -139,6 +140,14 @@ def minversion(module, version, inclusive=True, version_path='__version__'):
     else:
         have_version = resolve_name(module.__name__, version_path)
 
+    # LooseVersion raises a TypeError when strings like dev, rc1 are part
+    # of the version number. Match the dotted numbers only. Regex taken
+    # from PEP440, https://www.python.org/dev/peps/pep-0440/, Appendix B
+    expr = '^([1-9]\\d*!)?(0|[1-9]\\d*)(\\.(0|[1-9]\\d*))*'
+    m = re.match(expr, version)
+    if m:
+        version = m.group(0)
+
     if inclusive:
         return LooseVersion(have_version) >= LooseVersion(version)
     else:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/utils/tests/test_regression.py b/astropy/utils/tests/test_regression.py
new file mode 100644
index 0000000000..c9ef4f2b9c
--- /dev/null
+++ b/astropy/utils/tests/test_regression.py
@@ -0,0 +1,19 @@
+import pytest
+from types import ModuleType
+from astropy.utils.introspection import minversion
+
+
+def test_minversion_dev_comparison():
+    """
+    Regression test for a TypeError when comparing a version string to
+    a developer version string.
+
+    See: https://github.com/astropy/astropy/issues/7648
+    """
+    test_module = ModuleType(str("test_module"))
+    test_module.__version__ = '1.14.3'
+
+    # This comparison failed in LooseVersion because it would compare
+    # an integer with a string (e.g. 3 < 'dev').
+    # (see https://bugs.python.org/issue30272)
+    assert minversion(test_module, '1.14dev')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/utils/introspection\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/utils/tests/test_regression.py
cat coverage.cover
git checkout a7141cd90019b62688d507ae056298507678c058
git apply /root/pre_state.patch
