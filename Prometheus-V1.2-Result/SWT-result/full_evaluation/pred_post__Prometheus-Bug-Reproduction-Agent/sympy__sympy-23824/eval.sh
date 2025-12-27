#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 39de9a2698ad4bb90681c0fdb70b30a78233145f >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 39de9a2698ad4bb90681c0fdb70b30a78233145f
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/hep/gamma_matrices.py b/sympy/physics/hep/gamma_matrices.py
--- a/sympy/physics/hep/gamma_matrices.py
+++ b/sympy/physics/hep/gamma_matrices.py
@@ -694,8 +694,7 @@ def kahane_simplify(expression):
 
     # If `first_dum_pos` is not zero, it means that there are trailing free gamma
     # matrices in front of `expression`, so multiply by them:
-    for i in range(0, first_dum_pos):
-        [ri.insert(0, free_pos[i]) for ri in resulting_indices]
+    resulting_indices = list( free_pos[0:first_dum_pos] + ri for ri in resulting_indices )
 
     resulting_expr = S.Zero
     for i in resulting_indices:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/physics/hep/tests/test_kahane_simplify_bug.py b/sympy/physics/hep/tests/test_kahane_simplify_bug.py
new file mode 100644
index 0000000000..8c8248a356
--- /dev/null
+++ b/sympy/physics/hep/tests/test_kahane_simplify_bug.py
@@ -0,0 +1,19 @@
+from sympy.matrices import eye
+from sympy.physics.hep.gamma_matrices import GammaMatrix as G, kahane_simplify
+from sympy.physics.hep.gamma_matrices import LorentzIndex
+from sympy.tensor.tensor import tensor_indices, _is_tensor_eq
+
+
+def test_kahane_simplify_leading_uncontracted_bug():
+    """
+    Test for https://github.com/sympy/sympy/pull/23951
+    """
+    mu, nu, rho, sigma = tensor_indices("mu, nu, rho, sigma", LorentzIndex)
+
+    # This expression should simplify to 4*G(rho)*G(sigma)
+    # The bug causes it to become 4*G(sigma)*G(rho)
+    t = G(rho) * G(sigma) * G(mu) * G(-mu)
+    r = kahane_simplify(t)
+
+    # The assertion will fail due to the incorrect reversal of leading matrices
+    assert r.equals(4 * G(rho) * G(sigma))

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/physics/hep/gamma_matrices\.py)' bin/test -C --verbose sympy/physics/hep/tests/test_kahane_simplify_bug.p
cat coverage.cover
git checkout 39de9a2698ad4bb90681c0fdb70b30a78233145f
git apply /root/pre_state.patch
