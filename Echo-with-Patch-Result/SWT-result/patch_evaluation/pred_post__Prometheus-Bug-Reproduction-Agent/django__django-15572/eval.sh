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
diff --git a/tests/test_autoreload_empty_template_dir.py b/tests/test_autoreload_empty_template_dir.py
new file mode 100644
index 0000000000..0e9c942c55
--- /dev/null
+++ b/tests/test_autoreload_empty_template_dir.py
@@ -0,0 +1,23 @@
+from pathlib import Path
+
+from django.template.autoreload import get_template_directories
+from django.test import SimpleTestCase
+from django.test.utils import override_settings
+
+
+class AutoreloadEmptyTemplateDirTests(SimpleTestCase):
+    @override_settings(
+        TEMPLATES=[
+            {
+                "BACKEND": "django.template.backends.django.DjangoTemplates",
+                "DIRS": [""],
+            }
+        ]
+    )
+    def test_empty_template_dir_is_ignored(self):
+        """
+        An empty string in TEMPLATES DIRS should be ignored and not cause
+        the project root to be watched by the autoreloader.
+        """
+        template_dirs = get_template_directories()
+        self.assertNotIn(Path.cwd(), template_dirs)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/template/autoreload\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_autoreload_empty_template_dir
cat coverage.cover
git checkout 0b31e024873681e187b574fe1c4afe5e48aeeecf
git apply /root/pre_state.patch
