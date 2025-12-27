#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1923822ddf8265199dbd9ef9ce09641d3fd042b9 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1923822ddf8265199dbd9ef9ce09641d3fd042b9
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/solvers/diophantine.py b/sympy/solvers/diophantine.py
--- a/sympy/solvers/diophantine.py
+++ b/sympy/solvers/diophantine.py
@@ -182,7 +182,7 @@ def diophantine(eq, param=symbols("t", integer=True), syms=None,
             if syms != var:
                 dict_sym_index = dict(zip(syms, range(len(syms))))
                 return {tuple([t[dict_sym_index[i]] for i in var])
-                            for t in diophantine(eq, param)}
+                            for t in diophantine(eq, param, permute=permute)}
         n, d = eq.as_numer_denom()
         if n.is_number:
             return set()

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/solvers/tests/test_diophantine_issue.py b/sympy/solvers/tests/test_diophantine_issue.py
new file mode 100644
index 0000000000..846ab24cdd
--- /dev/null
+++ b/sympy/solvers/tests/test_diophantine_issue.py
@@ -0,0 +1,14 @@
+from sympy import symbols
+from sympy.solvers.diophantine import diophantine
+
+
+def test_diophantine_incomplete_results_syms_order():
+    """
+    Tests that the result of diophantine is independent of symbol order
+    when permute=True.
+    """
+    m, n = symbols('m, n', integer=True)
+    eq = n**4 + m**4 - 2**4 - 3**4
+    sol_mn = diophantine(eq, syms=(m, n), permute=True)
+    sol_nm = diophantine(eq, syms=(n, m), permute=True)
+    assert sol_nm == sol_mn

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/solvers/diophantine\.py)' bin/test -C --verbose sympy/solvers/tests/test_diophantine_issue.p
cat coverage.cover
git checkout 1923822ddf8265199dbd9ef9ce09641d3fd042b9
git apply /root/pre_state.patch
