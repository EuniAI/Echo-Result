#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 5f7a3a74aab1625c2bb65f643197ee885e3da576 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 5f7a3a74aab1625c2bb65f643197ee885e3da576
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install .
git apply -v - <<'EOF_114329324912'
diff --git a/test_binary_put.py b/test_binary_put.py
new file mode 100644
index 00000000..71f2b528
--- /dev/null
+++ b/test_binary_put.py
@@ -0,0 +1,46 @@
+import pytest
+import requests
+from requests.compat import is_py3, urljoin
+
+# Define the u() helper function for unicode literals, maintaining the style
+# from the provided test file.
+if is_py3:
+    def u(s):
+        return s
+else:
+    def u(s):
+        return s.decode('utf-8')
+
+# Define the httpbin fixture, as seen in the provided test file.
+# This assumes the 'httpbin' fixture from pytest-httpbin is available.
+@pytest.fixture
+def httpbin(httpbin):
+    """Make sure the URL always has a trailing slash."""
+    httpbin_url = httpbin.url.rstrip('/') + '/'
+
+    def inner(*suffix):
+        return urljoin(httpbin_url, '/'.join(suffix))
+
+    return inner
+
+
+class TestBinaryPut(object):
+    """
+    Test case for handling binary payloads in PUT requests.
+    """
+
+    def test_put_request_with_binary_payload(self, httpbin):
+        """
+        Tests that a PUT request with a binary payload (bytes) works correctly.
+
+        This test reproduces the bug reported in:
+        https://github.com/kennethreitz/requests/issues/2844
+        """
+        # In the buggy version, this call fails by raising an exception when
+        # trying to process the binary `data`.
+        # The fix ensures that binary data is handled correctly without errors.
+        response = requests.put(httpbin('put'), data=u('ööö').encode('utf-8'))
+
+        # A minimal assertion to confirm the request was successful. This will
+        # fail if an exception is raised, and will pass when the bug is fixed.
+        assert response.status_code == 200

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/models\.py)' -m pytest --no-header -rA  -p no:cacheprovider test_binary_put.py
cat coverage.cover
git checkout 5f7a3a74aab1625c2bb65f643197ee885e3da576
git apply /root/pre_state.patch
