#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2f13c476abe4ba787b6cb71131818341911f43cc >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2f13c476abe4ba787b6cb71131818341911f43cc
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_resolver_match.py b/tests/test_resolver_match.py
new file mode 100644
index 0000000000..c2443df72c
--- /dev/null
+++ b/tests/test_resolver_match.py
@@ -0,0 +1,41 @@
+import functools
+
+from django.test import SimpleTestCase
+from django.urls.resolvers import ResolverMatch
+
+
+def example_view(request, arg1, arg2):
+    pass
+
+
+class ResolverMatchReprTests(SimpleTestCase):
+    def test_repr_with_partial_func(self):
+        """
+        The repr of a ResolverMatch for a functools.partial view should
+        display the underlying function and its pre-filled arguments.
+        """
+        p = functools.partial(example_view, "arg1_val", arg2="arg2_val")
+        match = ResolverMatch(
+            func=p,
+            args=("url_arg",),
+            kwargs={"url_kwarg": "val"},
+            url_name="test-url",
+            app_names=["app"],
+            namespaces=["ns"],
+            route="test/route",
+        )
+        func_path = f"{example_view.__module__}.{example_view.__name__}"
+        expected_repr = (
+            "ResolverMatch(func=%s, args=%s, kwargs=%s, url_name=%s, "
+            "app_names=%s, namespaces=%s, route=%s)"
+            % (
+                func_path,
+                ("arg1_val", "url_arg"),
+                {"arg2": "arg2_val", "url_kwarg": "val"},
+                "test-url",
+                ["app"],
+                ["ns"],
+                "test/route",
+            )
+        )
+        self.assertEqual(repr(match), expected_repr)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/urls/resolvers\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_resolver_match
cat coverage.cover
git checkout 2f13c476abe4ba787b6cb71131818341911f43cc
git apply /root/pre_state.patch
