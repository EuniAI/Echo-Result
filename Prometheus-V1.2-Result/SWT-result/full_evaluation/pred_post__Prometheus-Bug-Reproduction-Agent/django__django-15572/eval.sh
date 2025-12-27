#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0b31e024873681e187b574fe1c4afe5e48aeeecf >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0b31e024873681e187b574fe1c4afe5e48aeeecf
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/template/autoreload.py b/django/template/autoreload.py
--- a/django/template/autoreload.py
+++ b/django/template/autoreload.py
@@ -17,7 +17,7 @@ def get_template_directories():
         if not isinstance(backend, DjangoTemplates):
             continue
 
-        items.update(cwd / to_path(dir) for dir in backend.engine.dirs)
+        items.update(cwd / to_path(dir) for dir in backend.engine.dirs if dir)
 
         for loader in backend.engine.template_loaders:
             if not hasattr(loader, "get_dirs"):
@@ -25,7 +25,7 @@ def get_template_directories():
             items.update(
                 cwd / to_path(directory)
                 for directory in loader.get_dirs()
-                if not is_django_path(directory)
+                if directory and not is_django_path(directory)
             )
     return items
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/test_autoreload_empty_dirs.py b/tests/template_tests/test_autoreload_empty_dirs.py
new file mode 100644
index 0000000000..a6468d3537
--- /dev/null
+++ b/tests/template_tests/test_autoreload_empty_dirs.py
@@ -0,0 +1,56 @@
+from pathlib import Path
+from unittest import mock
+
+from django.template import autoreload
+from django.test import SimpleTestCase, override_settings
+from django.test.utils import require_jinja2
+
+ROOT = Path(__file__).parent.absolute()
+EXTRA_TEMPLATES_DIR = ROOT / "templates_extra"
+
+
+@override_settings(
+    INSTALLED_APPS=["template_tests"],
+    TEMPLATES=[
+        {
+            "BACKEND": "django.template.backends.dummy.TemplateStrings",
+            "APP_DIRS": True,
+        },
+        {
+            "BACKEND": "django.template.backends.django.DjangoTemplates",
+            "DIRS": [EXTRA_TEMPLATES_DIR],
+            "OPTIONS": {
+                "context_processors": [
+                    "django.template.context_processors.request",
+                ],
+                "loaders": [
+                    "django.template.loaders.filesystem.Loader",
+                    "django.template.loaders.app_directories.Loader",
+                ],
+            },
+        },
+    ],
+)
+class TemplateReloadTests(SimpleTestCase):
+    @override_settings(
+        TEMPLATES=[
+            {
+                "BACKEND": "django.template.backends.django.DjangoTemplates",
+                "DIRS": [""],
+            }
+        ]
+    )
+    @mock.patch("django.template.autoreload.reset_loaders")
+    def test_empty_string_in_template_dirs(self, mock_reset):
+        """
+        An empty string in TEMPLATES DIRS shouldn't cause the autoreloader to
+        match all files.
+        """
+        # A non-template file with a template extension, located outside any
+        # legitimate template directory.
+        non_template_path = Path(__file__).with_suffix(".html")
+        # Due to the bug, template_changed() returns True for any .html file
+        # because '' is resolved to the project root. The correct behavior is
+        # to return None as this is not a real template.
+        self.assertIsNone(autoreload.template_changed(None, non_template_path))
+        mock_reset.assert_not_called()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/autoreload\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.test_autoreload_empty_dirs
cat coverage.cover
git checkout 0b31e024873681e187b574fe1c4afe5e48aeeecf
git apply /root/pre_state.patch
