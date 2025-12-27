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
diff --git a/astropy/wcs/wcsapi/wrappers/sliced_wcs.py b/astropy/wcs/wcsapi/wrappers/sliced_wcs.py
--- a/astropy/wcs/wcsapi/wrappers/sliced_wcs.py
+++ b/astropy/wcs/wcsapi/wrappers/sliced_wcs.py
@@ -243,6 +243,8 @@ def pixel_to_world_values(self, *pixel_arrays):
         return world_arrays
 
     def world_to_pixel_values(self, *world_arrays):
+        sliced_out_world_coords = self._pixel_to_world_values_all(*[0]*len(self._pixel_keep))
+
         world_arrays = tuple(map(np.asanyarray, world_arrays))
         world_arrays_new = []
         iworld_curr = -1
@@ -251,7 +253,7 @@ def world_to_pixel_values(self, *world_arrays):
                 iworld_curr += 1
                 world_arrays_new.append(world_arrays[iworld_curr])
             else:
-                world_arrays_new.append(1.)
+                world_arrays_new.append(sliced_out_world_coords[iworld])
 
         world_arrays_new = np.broadcast_arrays(*world_arrays_new)
         pixel_arrays = list(self._wcs.world_to_pixel_values(*world_arrays_new))

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/wcs/tests/test_regression.py b/astropy/wcs/tests/test_regression.py
new file mode 100644
index 0000000000..44cb13262b
--- /dev/null
+++ b/astropy/wcs/tests/test_regression.py
@@ -0,0 +1,61 @@
+import numpy as np
+from numpy.testing import assert_allclose
+
+import astropy.units as u
+import astropy.wcs
+from astropy.coordinates import SkyCoord
+from astropy.wcs.wcsapi import SlicedLowLevelWCS, HighLevelWCSWrapper
+import astropy.wcs.utils
+
+
+def test_sliced_wcs_world_to_pixel_coupling():
+    """
+    Regression test for an issue where world_to_pixel gives inconsistent
+    results when slicing a WCS with coupled spectral and spatial axes.
+
+    See https://github.com/astropy/astropy/issues/13242
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
+        'DATE-OBS': '2023-10-25T00:00:00'
+    }
+    fits_wcs = astropy.wcs.WCS(header=wcs_header)
+
+    frame = astropy.wcs.utils.wcs_to_celestial_frame(fits_wcs)
+    pt = SkyCoord(Tx=0 * u.arcsec, Ty=0 * u.arcsec, frame=frame)
+
+    # The slice is for the first wavelength. The '0' slices the first numpy
+    # axis, which corresponds to the last FITS WCS axis (wavelength).
+    ll_sliced_wcs = SlicedLowLevelWCS(fits_wcs, 0)
+    hl_sliced_wcs = HighLevelWCSWrapper(ll_sliced_wcs)
+
+    pixel_coords = hl_sliced_wcs.world_to_pixel(pt)
+
+    # The expected result is the center of the spatial axes, which are 0-indexed.
+    # CRPIX is 1-based, so we subtract 1.
+    expected_coords = (wcs_header['CRPIX1'] - 1, wcs_header['CRPIX2'] - 1)
+
+    assert_allclose(pixel_coords, expected_coords, rtol=1e-5)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/wcs/wcsapi/wrappers/sliced_wcs\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/wcs/tests/test_regression.py
cat coverage.cover
git checkout 0df94ff7097961e92fd7812036a24b145bc13ca8
git apply /root/pre_state.patch
