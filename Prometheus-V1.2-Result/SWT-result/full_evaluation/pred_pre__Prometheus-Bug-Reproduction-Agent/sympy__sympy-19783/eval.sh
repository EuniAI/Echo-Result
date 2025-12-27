#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 586a43201d0357e92e8c93548d69a9f42bf548f4 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 586a43201d0357e92e8c93548d69a9f42bf548f4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/quantum/tests/test_dagger_identity.py b/sympy/physics/quantum/tests/test_dagger_identity.py
new file mode 100644
index 0000000000..0d7142dcd4
--- /dev/null
+++ b/sympy/physics/quantum/tests/test_dagger_identity.py
@@ -0,0 +1,23 @@
+from sympy import (Derivative, diff, Function, Integer, Mul, pi, sin, Symbol,
+                   symbols)
+from sympy.physics.quantum.qexpr import QExpr
+from sympy.physics.quantum.dagger import Dagger
+from sympy.physics.quantum.hilbert import HilbertSpace
+from sympy.physics.quantum.operator import (Operator, UnitaryOperator,
+                                            HermitianOperator, OuterProduct,
+                                            DifferentialOperator,
+                                            IdentityOperator)
+from sympy.physics.quantum.state import Ket, Bra, Wavefunction
+from sympy.physics.quantum.qapply import qapply
+from sympy.physics.quantum.represent import represent
+from sympy.core.trace import Tr
+from sympy.physics.quantum.spin import JzKet, JzBra
+from sympy.matrices import eye
+
+
+def test_dagger_times_identity():
+    """Test that Dagger(A) * I simplifies to Dagger(A)"""
+    A = Operator('A')
+    identity = IdentityOperator()
+    B = Dagger(A)
+    assert B * identity == B

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/physics/quantum/operator\.py|sympy/physics/quantum/dagger\.py)' bin/test -C --verbose sympy/physics/quantum/tests/test_dagger_identity.p
cat coverage.cover
git checkout 586a43201d0357e92e8c93548d69a9f42bf548f4
git apply /root/pre_state.patch
