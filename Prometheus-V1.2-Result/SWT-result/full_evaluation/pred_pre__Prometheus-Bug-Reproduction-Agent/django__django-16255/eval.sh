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
diff --git a/tests/sitemaps_tests/test_views.py b/tests/sitemaps_tests/test_views.py
new file mode 100644
index 0000000000..97fc38ae6a
--- /dev/null
+++ b/tests/sitemaps_tests/test_views.py
@@ -0,0 +1,51 @@
+import datetime
+
+from django.contrib.sitemaps import Sitemap, views
+from django.urls import path
+from django.test import override_settings
+
+from .base import SitemapTestsBase
+
+
+class EmptyItemsCallableLastmodSitemap(Sitemap):
+    """
+    A sitemap with a callable `lastmod` but an empty `items` list to
+    reproduce the `ValueError` in `get_latest_lastmod`.
+    """
+
+    def items(self):
+        return []
+
+    def lastmod(self, item):
+        return datetime.date(2023, 1, 1)
+
+
+# A sitemaps dictionary containing the sitemap that causes the bug.
+sitemaps = {"test": EmptyItemsCallableLastmodSitemap}
+
+# The URL configuration for this test. It now includes the named URL
+# for the sitemap section view, which is required by the index view.
+urlpatterns = [
+    path("sitemap.xml", views.index, {"sitemaps": sitemaps}),
+    path(
+        "sitemap-<section>.xml",
+        views.sitemap,
+        {"sitemaps": sitemaps},
+        name="django.contrib.sitemaps.views.sitemap",
+    ),
+]
+
+
+@override_settings(ROOT_URLCONF=__name__)
+class SitemapEmptyCallableLastmodTests(SitemapTestsBase):
+    def test_sitemap_index_with_empty_items_and_callable_lastmod(self):
+        """
+        The sitemap index view should not raise a ValueError when a sitemap
+        has a callable `lastmod` but no items.
+        """
+        # This request to the index view triggers `get_latest_lastmod`.
+        # The bug causes a ValueError, resulting in a 500 server error.
+        # The test asserts that the response is successful (200 OK), which
+        # will only happen after the bug is fixed.
+        response = self.client.get("/sitemap.xml")
+        self.assertEqual(response.status_code, 200)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/sitemaps/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 sitemaps_tests.test_views
cat coverage.cover
git checkout 444b6da7cc229a58a2c476a52e45233001dc7073
git apply /root/pre_state.patch
