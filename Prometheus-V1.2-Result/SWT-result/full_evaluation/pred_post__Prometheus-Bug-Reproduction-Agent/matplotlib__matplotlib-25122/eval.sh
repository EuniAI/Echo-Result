#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5ec2bd279729ff534719b8bf238dbbca907b93c5 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5ec2bd279729ff534719b8bf238dbbca907b93c5
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/mlab.py b/lib/matplotlib/mlab.py
--- a/lib/matplotlib/mlab.py
+++ b/lib/matplotlib/mlab.py
@@ -395,12 +395,12 @@ def _spectral_helper(x, y=None, NFFT=None, Fs=None, detrend_func=None,
     elif mode == 'psd':
         result = np.conj(result) * result
     elif mode == 'magnitude':
-        result = np.abs(result) / np.abs(window).sum()
+        result = np.abs(result) / window.sum()
     elif mode == 'angle' or mode == 'phase':
         # we unwrap the phase later to handle the onesided vs. twosided case
         result = np.angle(result)
     elif mode == 'complex':
-        result /= np.abs(window).sum()
+        result /= window.sum()
 
     if mode == 'psd':
 
@@ -424,10 +424,10 @@ def _spectral_helper(x, y=None, NFFT=None, Fs=None, detrend_func=None,
             result /= Fs
             # Scale the spectrum by the norm of the window to compensate for
             # windowing loss; see Bendat & Piersol Sec 11.5.2.
-            result /= (np.abs(window)**2).sum()
+            result /= (window**2).sum()
         else:
             # In this case, preserve power in the segment, not amplitude
-            result /= np.abs(window).sum()**2
+            result /= window.sum()**2
 
     t = np.arange(NFFT/2, len(x) - NFFT/2 + 1, NFFT - noverlap)/Fs
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/lib/matplotlib/tests/test_mlab_psd.py b/lib/matplotlib/tests/test_mlab_psd.py
new file mode 100644
index 0000000000..4e5c3673b2
--- /dev/null
+++ b/lib/matplotlib/tests/test_mlab_psd.py
@@ -0,0 +1,45 @@
+from numpy.testing import assert_allclose
+import numpy as np
+
+from matplotlib import mlab
+
+def test_psd_window_with_negative_values():
+    """
+    Test that psd scaling is correct for windows with negative values.
+
+    The scaling for `scale_by_freq=False` should use `window.sum()**2`, but
+    was incorrectly using `np.abs(window).sum()**2`, giving incorrect
+    results for windows with negative lobes, such as a flattop window.
+
+    This test checks that the relationship between `scale_by_freq=True` and
+    `scale_by_freq=False` holds for a flattop window.
+    """
+    NFFT = 512
+    # A proper flattop window, which has negative values, matching the
+    # window from the issue report.
+    n = np.arange(NFFT)
+    a0 = 0.21557895
+    a1 = 0.41663158
+    a2 = 0.27726316
+    a3 = 0.08357895
+    a4 = 0.00694737
+    window = (a0 - a1 * np.cos(2 * np.pi * n / (NFFT - 1)) +
+              a2 * np.cos(4 * np.pi * n / (NFFT - 1)) -
+              a3 * np.cos(6 * np.pi * n / (NFFT - 1)) +
+              a4 * np.cos(8 * np.pi * n / (NFFT - 1)))
+
+    # A simple signal
+    x = np.random.randn(2 * NFFT)
+    Fs = 2.0
+
+    spec_s, _ = mlab.psd(x, NFFT=NFFT, Fs=Fs, window=window,
+                           scale_by_freq=True)
+
+    spec_n, _ = mlab.psd(x, NFFT=NFFT, Fs=Fs, window=window,
+                           scale_by_freq=False)
+
+    # This relationship should hold if the scaling is correct.
+    # It fails with the bug because spec_n is scaled by
+    # np.abs(window).sum()**2 instead of window.sum()**2.
+    assert_allclose(spec_s * (window**2).sum(),
+                    spec_n / Fs * window.sum()**2)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(lib/matplotlib/mlab\.py)' -m pytest --no-header -rA  -p no:cacheprovider lib/matplotlib/tests/test_mlab_psd.py
cat coverage.cover
git checkout 5ec2bd279729ff534719b8bf238dbbca907b93c5
git apply /root/pre_state.patch
