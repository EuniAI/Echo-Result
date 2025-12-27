#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e05cef574b8f23ab1b57f57e7da6dee509a4e230 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e05cef574b8f23ab1b57f57e7da6dee509a4e230
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/cmd/quickstart.py b/sphinx/cmd/quickstart.py
--- a/sphinx/cmd/quickstart.py
+++ b/sphinx/cmd/quickstart.py
@@ -95,6 +95,12 @@ def is_path(x: str) -> str:
     return x
 
 
+def is_path_or_empty(x: str) -> str:
+    if x == '':
+        return x
+    return is_path(x)
+
+
 def allow_empty(x: str) -> str:
     return x
 
@@ -223,7 +229,7 @@ def ask_user(d: Dict) -> None:
         print(__('sphinx-quickstart will not overwrite existing Sphinx projects.'))
         print()
         d['path'] = do_prompt(__('Please enter a new root path (or just Enter to exit)'),
-                              '', is_path)
+                              '', is_path_or_empty)
         if not d['path']:
             sys.exit(1)
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_quickstart_exit_on_existing_conf.py b/tests/test_quickstart_exit_on_existing_conf.py
new file mode 100644
index 000000000..7a07adcab
--- /dev/null
+++ b/tests/test_quickstart_exit_on_existing_conf.py
@@ -0,0 +1,61 @@
+import os
+import time
+from io import StringIO
+
+import pytest
+
+from sphinx.cmd import quickstart as qs
+from sphinx.util.console import coloron, nocolor
+
+warnfile = StringIO()
+
+
+def setup_module():
+    nocolor()
+
+
+def mock_input(answers, needanswer=False):
+    called = set()
+
+    def input_(prompt):
+        if prompt in called:
+            raise AssertionError('answer for %r missing and no default '
+                                 'present' % prompt)
+        called.add(prompt)
+        for question in answers:
+            if prompt.startswith(qs.PROMPT_PREFIX + question):
+                return answers[question]
+        if needanswer:
+            raise AssertionError('answer for %r missing' % prompt)
+        return ''
+    return input_
+
+
+real_input = input
+
+
+def teardown_module():
+    qs.term_input = real_input
+    coloron()
+
+
+def test_quickstart_exit_on_existing_conf(tempdir):
+    """Test sphinx-quickstart exits if conf.py exists and user hits Enter."""
+    # Create an existing conf.py file using a robust, basic method.
+    conf_py_path = os.path.join(str(tempdir), 'conf.py')
+    with open(conf_py_path, 'w') as f:
+        pass
+
+    # Mock input: Answer the first "Root path" question with the tempdir,
+    # then provide no answer for the subsequent prompt, simulating Enter.
+    answers = {
+        'Root path': str(tempdir),
+    }
+    qs.term_input = mock_input(answers)
+
+    d = {}
+    # The bug is that sphinx-quickstart does not exit. When fixed, it should
+    # raise SystemExit. The test will currently fail because the prompt is
+    # repeated, causing an AssertionError from the mock_input helper.
+    with pytest.raises(SystemExit):
+        qs.ask_user(d)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/cmd/quickstart\.py)' -m tox -epy39 -v -- tests/test_quickstart_exit_on_existing_conf.py
cat coverage.cover
git checkout e05cef574b8f23ab1b57f57e7da6dee509a4e230
git apply /root/pre_state.patch
