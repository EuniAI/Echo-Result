#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 091991be0da19de9108dbe5e3752917fea3d7fdc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 091991be0da19de9108dbe5e3752917fea3d7fdc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install .
git apply -v - <<'EOF_114329324912'
diff --git a/requests/sessions.py b/requests/sessions.py
--- a/requests/sessions.py
+++ b/requests/sessions.py
@@ -13,7 +13,7 @@
 from datetime import datetime
 
 from .auth import _basic_auth_str
-from .compat import cookielib, OrderedDict, urljoin, urlparse, builtin_str
+from .compat import cookielib, OrderedDict, urljoin, urlparse
 from .cookies import (
     cookiejar_from_dict, extract_cookies_to_jar, RequestsCookieJar, merge_cookies)
 from .models import Request, PreparedRequest, DEFAULT_REDIRECT_LIMIT
@@ -425,7 +425,7 @@ def request(self, method, url,
             If Tuple, ('cert', 'key') pair.
         """
 
-        method = builtin_str(method)
+        method = to_native_string(method)
 
         # Create the Request.
         req = Request(

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/test_binary_request_method.py b/test_binary_request_method.py
new file mode 100644
index 00000000..cdbbafb1
--- /dev/null
+++ b/test_binary_request_method.py
@@ -0,0 +1,29 @@
+import os
+import unittest
+import requests
+from requests.compat import urljoin, is_py3, builtin_str
+
+
+if is_py3:
+    def u(s):
+        return s
+else:
+    def u(s):
+        return s.decode('unicode-escape')
+
+HTTPBIN = os.environ.get('HTTPBIN_URL', 'http://httpbin.org/')
+HTTPBIN = HTTPBIN.rstrip('/') + '/'
+
+
+def httpbin(*suffix):
+    """Returns url for HTTPBIN resource."""
+    return urljoin(HTTPBIN, '/'.join(suffix))
+
+
+class RequestsTestCase(unittest.TestCase):
+
+    def test_binary_method_name(self):
+        """Test that requests work with binary method names."""
+        r = requests.request(method=b'GET', url=httpbin('get'))
+
+        self.assertEqual(r.status_code, 200)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/sessions\.py)' -m pytest --no-header -rA  -p no:cacheprovider test_binary_request_method.py
cat coverage.cover
git checkout 091991be0da19de9108dbe5e3752917fea3d7fdc
git apply /root/pre_state.patch
