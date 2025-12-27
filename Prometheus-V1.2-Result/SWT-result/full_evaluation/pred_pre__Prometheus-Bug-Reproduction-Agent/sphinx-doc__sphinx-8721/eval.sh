#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 82ef497a8c88f0f6e50d84520e7276bfbf65025d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 82ef497a8c88f0f6e50d84520e7276bfbf65025d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_viewcode_multibuild.py b/tests/test_ext_viewcode_multibuild.py
new file mode 100644
index 000000000..93b96e240
--- /dev/null
+++ b/tests/test_ext_viewcode_multibuild.py
@@ -0,0 +1,32 @@
+import pytest
+
+
+@pytest.mark.sphinx('html', testroot='ext-viewcode')
+def test_viewcode_does_not_create_epub_files_on_multi_build(app, make_app):
+    """
+    Tests that viewcode does not generate module pages for epub
+    when `viewcode_enable_epub=False`, even after an html build
+    has already run. This simulates the `make html epub` scenario.
+    """
+    # 1. Run the initial 'html' build. This populates the doctree cache
+    # with entries for the viewcode-generated module pages.
+    app.build()
+    assert (app.outdir / '_modules').exists()
+
+    # 2. Create and run an 'epub' build.
+    # We instruct this build to use the *same doctree directory* as the
+    # previous html build by setting the 'doctreedir' config value.
+    epub_app = make_app(
+        'epub',
+        srcdir=app.srcdir,
+        confoverrides={
+            'viewcode_enable_epub': False,
+            'doctreedir': app.doctreedir,
+        }
+    )
+    epub_app.build()
+
+    # 3. Assert that the `_modules` directory was NOT created in the epub output.
+    # Due to the bug, the epub build incorrectly processes the doctree entries
+    # from the html build, creating the files. This assertion will therefore FAIL.
+    assert not (epub_app.outdir / '_modules').exists()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/viewcode\.py)' -m tox -epy39 -v -- tests/test_ext_viewcode_multibuild.py
cat coverage.cover
git checkout 82ef497a8c88f0f6e50d84520e7276bfbf65025d
git apply /root/pre_state.patch
