#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0192aac24123735b3eaf9b08df46429bb770c283 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0192aac24123735b3eaf9b08df46429bb770c283
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install .
git apply -v - <<'EOF_114329324912'
diff --git a/requests/utils.py b/requests/utils.py
--- a/requests/utils.py
+++ b/requests/utils.py
@@ -974,6 +974,10 @@ def prepend_scheme_if_needed(url, new_scheme):
     if not netloc:
         netloc, path = path, netloc
 
+    if auth:
+        # parse_url doesn't provide the netloc with auth
+        # so we'll add it ourselves.
+        netloc = '@'.join([auth, netloc])
     if scheme is None:
         scheme = new_scheme
     if path is None:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_proxy.py b/tests/test_proxy.py
new file mode 100644
index 00000000..c9faad6f
--- /dev/null
+++ b/tests/test_proxy.py
@@ -0,0 +1,47 @@
+# -*- coding: utf-8 -*-
+import pytest
+import requests
+from unittest.mock import patch, Mock
+
+
+def test_proxy_authentication_header_is_sent():
+    """
+    Verifies that credentials in a proxy URL are sent as a
+    'Proxy-Authorization' header.
+
+    This test patches the underlying `urlopen` call in `urllib3` to
+    intercept the request before it goes over the network. This allows us
+    to inspect the headers that `requests` prepares for the proxied
+    request and assert that the `Proxy-Authorization` header is present.
+    """
+    # The target to patch is the low-level method in urllib3 that sends requests.
+    patch_target = 'urllib3.connectionpool.HTTPConnectionPool.urlopen'
+
+    with patch(patch_target, autospec=True) as mock_urlopen:
+        # We must provide a mock response object for requests to process.
+        mock_response = Mock()
+        mock_response.status = 200
+        mock_response.headers = {}
+        # This is needed to prevent errors in redirect handling.
+        mock_response.get_redirect_location.return_value = None
+        mock_urlopen.return_value = mock_response
+
+        proxies = {
+            'http': 'http://user:pass@myproxy.com:8080'
+        }
+
+        # Use stream=True to prevent requests from trying to iterate over the
+        # response body. Our mock is not iterable, and we don't care about
+        # the body anyway. This resolves the TypeError.
+        requests.get('http://example.com/', proxies=proxies, stream=True)
+
+        # Ensure the low-level send method was actually called.
+        mock_urlopen.assert_called_once()
+
+        # Extract the headers from the arguments passed to urlopen.
+        call_kwargs = mock_urlopen.call_args.kwargs
+        sent_headers = call_kwargs['headers']
+
+        # This is the minimal assertion that will fail if the bug is present
+        # and pass when the bug is fixed.
+        assert 'Proxy-Authorization' in sent_headers

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(requests/utils\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/test_proxy.py
cat coverage.cover
git checkout 0192aac24123735b3eaf9b08df46429bb770c283
git apply /root/pre_state.patch
