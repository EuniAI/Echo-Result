#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1a4462d72eb03f30dc83a879b1dd57aac8b2c18b >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1a4462d72eb03f30dc83a879b1dd57aac8b2c18b
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test] --verbose
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/coordinates/sky_coordinate.py b/astropy/coordinates/sky_coordinate.py
--- a/astropy/coordinates/sky_coordinate.py
+++ b/astropy/coordinates/sky_coordinate.py
@@ -894,10 +894,8 @@ def __getattr__(self, attr):
             if frame_cls is not None and self.frame.is_transformable_to(frame_cls):
                 return self.transform_to(attr)
 
-        # Fail
-        raise AttributeError(
-            f"'{self.__class__.__name__}' object has no attribute '{attr}'"
-        )
+        # Call __getattribute__; this will give correct exception.
+        return self.__getattribute__(attr)
 
     def __setattr__(self, attr, val):
         # This is to make anything available through __getattr__ immutable

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/astropy/coordinates/tests/test_skycoord_subclass.py b/astropy/coordinates/tests/test_skycoord_subclass.py
new file mode 100644
index 0000000000..66ba9d714e
--- /dev/null
+++ b/astropy/coordinates/tests/test_skycoord_subclass.py
@@ -0,0 +1,25 @@
+import pytest
+
+from astropy import units as u
+from astropy.coordinates import SkyCoord
+
+
+def test_subclass_attribute_error():
+    """
+    Test that a subclass of SkyCoord with a property that accesses a non-existent
+    attribute provides a clear error message. This is a regression test for
+    a bug where the error message was misleadingly reporting that the property
+    itself did not exist.
+    """
+
+    class CustomCoord(SkyCoord):
+        @property
+        def prop(self):
+            return self.random_attr
+
+    c = CustomCoord("00h42m30s", "+41d12m00s", frame="icrs")
+
+    with pytest.raises(AttributeError) as excinfo:
+        c.prop
+
+    assert "has no attribute 'random_attr'" in str(excinfo.value)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(astropy/coordinates/sky_coordinate\.py)' -m pytest --no-header -rA  -p no:cacheprovider astropy/coordinates/tests/test_skycoord_subclass.py
cat coverage.cover
git checkout 1a4462d72eb03f30dc83a879b1dd57aac8b2c18b
git apply /root/pre_state.patch
