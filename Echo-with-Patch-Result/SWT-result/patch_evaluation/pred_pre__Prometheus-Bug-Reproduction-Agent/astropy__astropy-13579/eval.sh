#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0df94ff7097961e92fd7812036a24b145bc13ca8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0df94ff7097961e92fd7812036a24b145bc13ca8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/wcs/tests/test_sliced_wcs_issue12739.py b/astropy/wcs/tests/test_sliced_wcs_issue12739.py
new file mode 100644
index 0000000000..aa82056dc9
--- /dev/null
+++ b/astropy/wcs/tests/test_sliced_wcs_issue12739.py
@@ -0,0 +1,71 @@
+import numpy as np
+from numpy.testing import assert_allclose
+import pytest
+
+import astropy.units as u
+import astropy.wcs
+from astropy.coordinates import SkyCoord
+from astropy.wcs.wcsapi import SlicedLowLevelWCS, HighLevelWCSWrapper
+
+
+def test_sliced_world_to_pixel_coupled():
+    """
+    Regression test for issue where world_to_pixel on a SlicedLowLevelWCS
+    with coupled axes gives an incorrect result.
+
+    This test calls the high-level world_to_pixel wrapper with two separate
+    Quantity objects to satisfy the argument parser, which in this test
+    environment expects two world objects instead of a single SkyCoord.
+    This allows the test to reach the underlying buggy code.
+
+    See: https://github.com/astropy/astropy/issues/12739
+    """
+    nx = 100
+    ny = 25
+    wcs_header = {
+        'WCSAXES': 3,
+        'CRPIX1': (nx + 1) / 2,
+        'CRPIX2': (ny + 1) / 2,
+        'CRPIX3': 1.0,
+        'PC1_1': 0.0,
+        'PC1_2': -1.0,
+        'PC1_3': 0.0,
+        'PC2_1': 1.0,
+        'PC2_2': 0.0,
+        'PC2_3': -1.0,
+        'CDELT1': 5,
+        'CDELT2': 5,
+        'CDELT3': 0.055,
+        'CUNIT1': 'arcsec',
+        'CUNIT2': 'arcsec',
+        'CUNIT3': 'Angstrom',
+        'CTYPE1': 'HPLN-TAN',
+        'CTYPE2': 'HPLT-TAN',
+        'CTYPE3': 'WAVE',
+        'CRVAL1': 0.0,
+        'CRVAL2': 0.0,
+        'CRVAL3': 1.05,
+    }
+    fits_wcs = astropy.wcs.WCS(header=wcs_header)
+
+    # The slice is on the wavelength axis (last WCS axis), at pixel index 0.
+    ll_sliced_wcs = SlicedLowLevelWCS(fits_wcs, 0)
+    hl_sliced_wcs = HighLevelWCSWrapper(ll_sliced_wcs)
+
+    # Input world coordinates for the sliced (2D) WCS.
+    # We pass them as two separate Quantities to match what the high-level
+    # API expects in this context.
+    tx = 0 * u.arcsec
+    ty = 0 * u.arcsec
+
+    # This is the call that exhibits the bug.
+    pixel_out = hl_sliced_wcs.world_to_pixel(tx, ty)
+
+    # The expected output from the bug report, which is the correct pixel
+    # coordinates for the given world coordinates.
+    expected_pixel_coords = (49.5, 12.0)
+
+    # The bug causes the first value to be ~1.8e11. This assertion will fail.
+    # It will pass when the underlying SlicedLowLevelWCS uses the correct
+    # reference world value for the dropped dimension.
+    assert_allclose(pixel_out, expected_pixel_coords)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/wcs/wcsapi/wrappers/sliced_wcs\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/wcs/tests/test_sliced_wcs_issue12739.py
cat coverage.cover
git checkout 0df94ff7097961e92fd7812036a24b145bc13ca8
git apply /root/pre_state.patch
