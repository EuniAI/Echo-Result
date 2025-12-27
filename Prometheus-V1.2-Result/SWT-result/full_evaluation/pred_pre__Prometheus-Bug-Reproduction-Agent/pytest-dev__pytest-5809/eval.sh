#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 8aba863a634f40560e25055d179220f0eefabe9a >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 8aba863a634f40560e25055d179220f0eefabe9a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/testing/test_pastebin_lexer.py b/testing/test_pastebin_lexer.py
new file mode 100644
index 000000000..5572dac02
--- /dev/null
+++ b/testing/test_pastebin_lexer.py
@@ -0,0 +1,67 @@
+# -*- coding: utf-8 -*-
+from __future__ import absolute_import
+from __future__ import division
+from __future__ import print_function
+
+import sys
+
+import pytest
+
+
+class TestPaste(object):
+    @pytest.fixture
+    def pastebin(self, request):
+        return request.config.pluginmanager.getplugin("pastebin")
+
+    def test_pastebin_lexer_for_arbitrary_text(self, pastebin, monkeypatch):
+        """
+        Tests that pastebin uploads use 'text' lexer to avoid HTTP errors.
+
+        The bpaste.net service can fail with a HTTP 400 error if the content
+        of the paste is not valid for the specified lexer. Pytest terminal
+        output is not Python code, so 'python3' or 'python' lexers are
+        inappropriate. This test mocks urlopen to simulate this failure, and
+        will pass when the correct 'text' lexer is used.
+        """
+
+        def mock_urlopen_bpaste(url, data):
+            if sys.version_info >= (3, 0):
+                from urllib.parse import parse_qs
+                from urllib.error import HTTPError
+                from io import BytesIO
+
+                params = parse_qs(data.decode("ascii"))
+                fp = BytesIO(b"")
+            else:
+                from urlparse import parse_qs
+                from urllib2 import HTTPError
+
+                params = parse_qs(data)
+                fp = None
+
+            lexer = params.get("lexer", [None])[0]
+            if lexer and lexer != "text":
+                raise HTTPError(url, 400, "Bad Request", {}, fp)
+
+            class DummyFile:
+                def read(self):
+                    return b'View <a href="/raw/3c0c6750bd">raw</a>.'
+
+            return DummyFile()
+
+        if sys.version_info < (3, 0):
+            import urllib
+
+            monkeypatch.setattr(urllib, "urlopen", mock_urlopen_bpaste)
+        else:
+            import urllib.request
+
+            monkeypatch.setattr(urllib.request, "urlopen", mock_urlopen_bpaste)
+
+        # Some content that is not valid python.
+        content = b"=== 1 failed, 1 passed in 0.12s ==="
+
+        # This call will raise HTTPError with the current buggy code.
+        # With the fix (lexer='text'), it should pass.
+        result = pastebin.create_new_paste(content)
+        assert result == "https://bpaste.net/show/3c0c6750bd"

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(src/_pytest/pastebin\.py)' -m pytest -rA testing/test_pastebin_lexer.py
cat coverage.cover
git checkout 8aba863a634f40560e25055d179220f0eefabe9a
git apply /root/pre_state.patch
