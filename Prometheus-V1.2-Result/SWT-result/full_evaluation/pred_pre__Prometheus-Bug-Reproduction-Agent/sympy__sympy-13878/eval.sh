#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 7b127bdf71a36d85216315f80c1b54d22b060818 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 7b127bdf71a36d85216315f80c1b54d22b060818
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/stats/tests/test_continuous_rv_issue_13926.py b/sympy/stats/tests/test_continuous_rv_issue_13926.py
new file mode 100644
index 0000000000..9d094b7390
--- /dev/null
+++ b/sympy/stats/tests/test_continuous_rv_issue_13926.py
@@ -0,0 +1,35 @@
+from __future__ import division
+from sympy.stats import (P, E, where, density, variance, covariance, skewness,
+                         given, pspace, cdf, characteristic_function, ContinuousRV, sample,
+                         Arcsin, Benini, Beta, BetaPrime, Cauchy,
+                         Chi, ChiSquared,
+                         ChiNoncentral, Dagum, Erlang, Exponential,
+                         FDistribution, FisherZ, Frechet, Gamma, GammaInverse,
+                         Gompertz, Gumbel, Kumaraswamy, Laplace, Logistic,
+                         LogNormal, Maxwell, Nakagami, Normal, Pareto,
+                         QuadraticU, RaisedCosine, Rayleigh, ShiftedGompertz,
+                         StudentT, Trapezoidal, Triangular, Uniform, UniformSum,
+                         VonMises, Weibull, WignerSemicircle, correlation,
+                         moment, cmoment, smoment)
+
+from sympy import (Symbol, Abs, exp, S, N, pi, simplify, Interval, erf, erfc,
+                   Eq, log, lowergamma, Sum, symbols, sqrt, And, gamma, beta,
+                   Piecewise, Integral, sin, cos, besseli, factorial, binomial,
+                   floor, expand_func, Rational, I)
+
+from sympy.utilities.pytest import raises, XFAIL, slow
+
+from sympy.core.compatibility import range
+
+oo = S.Infinity
+
+x, y, z = map(Symbol, 'xyz')
+
+def test_laplace_cdf_issue_13926():
+    """
+    Test for the CDF of the Laplace distribution from issue 13926.
+
+    The CDF for Laplace was not precomputed and failed to integrate,
+    returning an unevaluated Integral object instead of a symbolic value.
+    """
+    assert cdf(Laplace("x", 2, 3))(5) == 1 - S.Half * exp(-1)

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/stats/crv_types\.py)' bin/test -C --verbose sympy/stats/tests/test_continuous_rv_issue_13926.p
cat coverage.cover
git checkout 7b127bdf71a36d85216315f80c1b54d22b060818
git apply /root/pre_state.patch
