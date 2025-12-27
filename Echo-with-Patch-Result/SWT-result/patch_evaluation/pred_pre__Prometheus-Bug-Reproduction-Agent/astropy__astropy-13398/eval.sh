#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 6500928dc0e57be8f06d1162eacc3ba5e2eff692 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 6500928dc0e57be8f06d1162eacc3ba5e2eff692
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/coordinates/tests/test_itrs_direct_transform.py b/astropy/coordinates/tests/test_itrs_direct_transform.py
new file mode 100644
index 0000000000..d46acb6c73
--- /dev/null
+++ b/astropy/coordinates/tests/test_itrs_direct_transform.py
@@ -0,0 +1,28 @@
+import numpy as np
+import pytest
+
+from astropy import units as u
+from astropy.coordinates import ITRS
+from astropy.tests.helper import assert_quantity_allclose
+from astropy.time import Time
+
+
+def test_itrs_to_itrs_direct_transform():
+    """
+    Test that ITRS to ITRS transforms with different obstimes do not change
+    the coordinates, as should be the case for a direct transform.
+    This is for the issue raised in gh-13319.
+    """
+    # A point that is fixed in the ITRS frame
+    itrs_coo1 = ITRS(x=1000 * u.km, y=2000 * u.km, z=3000 * u.km,
+                     obstime="J2000")
+
+    # Transform to a different obstime
+    itrs_coo2 = itrs_coo1.transform_to(ITRS(obstime="J2010"))
+
+    # Without the direct transform, this will fail. It might fail with a
+    # TypeError, or it might give a large coordinate difference because it
+    # incorrectly goes through a sky frame (e.g., ICRS). With the fix, a
+    # direct transform is used, and the cartesian values should be nearly
+    # identical.
+    assert_quantity_allclose(itrs_coo1.cartesian.xyz, itrs_coo2.cartesian.xyz, atol=1 * u.mm)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/coordinates/builtin_frames/__init__\.py|astropy/coordinates/builtin_frames/intermediate_rotation_transforms\.py|astropy/coordinates/builtin_frames/itrs_observed_transforms\.py|astropy/coordinates/builtin_frames/itrs\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/coordinates/tests/test_itrs_direct_transform.py
cat coverage.cover
git checkout 6500928dc0e57be8f06d1162eacc3ba5e2eff692
git apply /root/pre_state.patch
