#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD cffd4e0f86fefd4802349a9f9b19ed70934ea354 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff cffd4e0f86fefd4802349a9f9b19ed70934ea354
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/_print_helpers.py b/sympy/core/_print_helpers.py
--- a/sympy/core/_print_helpers.py
+++ b/sympy/core/_print_helpers.py
@@ -17,6 +17,11 @@ class Printable:
     This also adds support for LaTeX printing in jupyter notebooks.
     """
 
+    # Since this class is used as a mixin we set empty slots. That means that
+    # instances of any subclasses that use slots will not need to have a
+    # __dict__.
+    __slots__ = ()
+
     # Note, we always use the default ordering (lex) in __str__ and __repr__,
     # regardless of the global setting. See issue 5487.
     def __str__(self):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/core/tests/test_symbol_2.py b/sympy/core/tests/test_symbol_2.py
new file mode 100644
index 0000000000..76705bc503
--- /dev/null
+++ b/sympy/core/tests/test_symbol_2.py
@@ -0,0 +1,16 @@
+from sympy import (Symbol, Wild, GreaterThan, LessThan, StrictGreaterThan,
+    StrictLessThan, pi, I, Rational, sympify, symbols, Dummy)
+from sympy.core.symbol import uniquely_named_symbol, _symbol, Str
+
+from sympy.testing.pytest import raises
+from sympy.core.symbol import disambiguate
+
+
+def test_symbol_no_dict():
+    """
+    Tests that Symbol instances do not have a __dict__ attribute.
+
+    This was present in older versions of SymPy for memory optimization
+    and was accidentally removed in 1.7.
+    """
+    assert not hasattr(Symbol('s'), '__dict__')

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/core/_print_helpers\.py)' bin/test -C --verbose sympy/core/tests/test_symbol_2.p
cat coverage.cover
git checkout cffd4e0f86fefd4802349a9f9b19ed70934ea354
git apply /root/pre_state.patch
