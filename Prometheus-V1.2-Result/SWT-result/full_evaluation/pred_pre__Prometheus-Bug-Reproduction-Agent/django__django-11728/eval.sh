#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 05457817647368be4b019314fcc655445a5b4c0c >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 05457817647368be4b019314fcc655445a5b4c0c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/urlpatterns/test_patterns.py b/tests/urlpatterns/test_patterns.py
new file mode 100644
index 0000000000..ee1781d141
--- /dev/null
+++ b/tests/urlpatterns/test_patterns.py
@@ -0,0 +1,20 @@
+from django.test import SimpleTestCase
+from django.test.utils import override_settings
+from django.urls.resolvers import RegexPattern, RoutePattern, get_resolver
+from django.utils.translation import gettext_lazy as _
+
+
+class RegexPatternTests(SimpleTestCase):
+    def test_simplify_regexp_replaces_trailing_group_without_trailing_slash(self):
+        """
+        Test that simplify_regexp() (i.e. RegexPattern.describe()) replaces
+        the final named group in a URL pattern that is missing a trailing
+        slash.
+        """
+        pattern = RegexPattern(
+            r'entries/(?P<pk>[^/.]+)/relationships/(?P<related_field>\w+)'
+        )
+        self.assertEqual(
+            pattern.describe(),
+            'entries/<pk>/relationships/<related_field>'
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admindocs/utils\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 urlpatterns.test_patterns
cat coverage.cover
git checkout 05457817647368be4b019314fcc655445a5b4c0c
git apply /root/pre_state.patch
