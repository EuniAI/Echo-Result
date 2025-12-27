#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 1e2ccd8f0eca0870cf6f8fce6934e2da8eba9b72 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 1e2ccd8f0eca0870cf6f8fce6934e2da8eba9b72
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/builders/linkcheck.py b/sphinx/builders/linkcheck.py
--- a/sphinx/builders/linkcheck.py
+++ b/sphinx/builders/linkcheck.py
@@ -166,6 +166,7 @@ def check_uri() -> Tuple[str, str, int]:
                     # Read the whole document and see if #anchor exists
                     response = requests.get(req_url, stream=True, config=self.app.config,
                                             auth=auth_info, **kwargs)
+                    response.raise_for_status()
                     found = check_anchor(response, unquote(anchor))
 
                     if not found:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_build_linkcheck_http_error.py b/tests/test_build_linkcheck_http_error.py
new file mode 100644
index 000000000..dc5d6bd3e
--- /dev/null
+++ b/tests/test_build_linkcheck_http_error.py
@@ -0,0 +1,36 @@
+import pytest
+from unittest import mock
+import requests
+
+
+@pytest.mark.sphinx('linkcheck', testroot='linkcheck', freshenv=True)
+def test_http_error_with_anchor(app, status, warning):
+    """
+    Test that linkcheck reports HTTP errors before checking for anchors.
+
+    A link to a non-existent page with an anchor should report the page's
+    HTTP error, not a failed anchor lookup.
+
+    Regression test for https://github.com/sphinx-doc/sphinx/issues/8191.
+    """
+    (app.srcdir / 'index.rst').write_text(
+        '`foo <https://google.com/test.txt#test>`_'
+    )
+
+    # Simulate a 404 Not Found error for the page.
+    # The linkchecker uses a requests.Session object.
+    error = requests.HTTPError(
+        '404 Client Error: Not Found for url: https://google.com/test.txt'
+    )
+    with mock.patch('requests.Session.head', side_effect=error), \
+            mock.patch('requests.Session.get', side_effect=error):
+        app.builder.build_all()
+
+    content = (app.outdir / 'output.txt').read_text()
+
+    # The bug causes an "Anchor not found" message. The fix should show the
+    # underlying HTTP error instead.
+    expected_error_message = (
+        '404 Client Error: Not Found for url: https://google.com/test.txt'
+    )
+    assert expected_error_message in content

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/builders/linkcheck\.py)' -m tox -epy39 -v -- tests/test_build_linkcheck_http_error.py
cat coverage.cover
git checkout 1e2ccd8f0eca0870cf6f8fce6934e2da8eba9b72
git apply /root/pre_state.patch
