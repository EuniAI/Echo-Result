#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 444b6da7cc229a58a2c476a52e45233001dc7073 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 444b6da7cc229a58a2c476a52e45233001dc7073
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_sitemaps_lastmod.py b/tests/test_sitemaps_lastmod.py
new file mode 100644
index 0000000000..8fcce76dd0
--- /dev/null
+++ b/tests/test_sitemaps_lastmod.py
@@ -0,0 +1,26 @@
+from datetime import datetime
+
+from django.contrib.sitemaps import Sitemap
+from django.test import TestCase
+
+
+class SitemapCallableLastmodEmptyItemsTests(TestCase):
+    def test_get_latest_lastmod_empty_items_callable_lastmod(self):
+        """
+        Sitemap.get_latest_lastmod() should not raise a ValueError when
+        lastmod is a callable and items() is empty.
+        """
+
+        class EmptySitemap(Sitemap):
+            def items(self):
+                return []
+
+            def lastmod(self, item):
+                return datetime.now()
+
+        sitemap = EmptySitemap()
+        # Before the patch, this call raises a ValueError because max()
+        # is called on an empty sequence. After the patch, it correctly
+        # returns None.
+        latest_lastmod = sitemap.get_latest_lastmod()
+        self.assertIsNone(latest_lastmod)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/sitemaps/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_sitemaps_lastmod
cat coverage.cover
git checkout 444b6da7cc229a58a2c476a52e45233001dc7073
git apply /root/pre_state.patch
