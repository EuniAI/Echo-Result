#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 40cc2ffd7887959157aaf469e09585ec2be7f528 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 40cc2ffd7887959157aaf469e09585ec2be7f528
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/pylint/checkers/similar.py b/pylint/checkers/similar.py
--- a/pylint/checkers/similar.py
+++ b/pylint/checkers/similar.py
@@ -390,6 +390,8 @@ def append_stream(self, streamid: str, stream: TextIO, encoding=None) -> None:
 
     def run(self) -> None:
         """start looking for similarities and display results on stdout"""
+        if self.min_lines == 0:
+            return
         self._display_sims(self._compute_sims())
 
     def _compute_sims(self) -> List[Tuple[int, Set[LinesChunkLimits_T]]]:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/checkers/test_min_similarity_lines_zero.py b/tests/checkers/test_min_similarity_lines_zero.py
new file mode 100644
index 000000000..9833e846c
--- /dev/null
+++ b/tests/checkers/test_min_similarity_lines_zero.py
@@ -0,0 +1,49 @@
+from pathlib import Path
+
+import pytest
+
+from pylint.checkers import similar
+from pylint.lint import PyLinter
+from pylint.testutils import GenericTestReporter as Reporter
+
+
+def test_min_similarity_lines_zero_disables_check(tmp_path: Path) -> None:
+    """Test that min-similarity-lines=0 disables the similarity check.
+
+    Setting min-similarity-lines to 0 should disable the duplicate code
+    check entirely. This test ensures that when the option is set to 0,
+    no 'duplicate-code' messages are emitted for files with obvious
+    similarities.
+    """
+    file1_content = """
+import one
+from two import two
+three
+four
+five
+six
+"""
+    file2_content = """
+import one
+from two import two
+three
+four
+five
+seven
+"""
+    file1 = tmp_path / "file1.py"
+    file1.write_text(file1_content, encoding="utf-8")
+    file2 = tmp_path / "file2.py"
+    file2.write_text(file2_content, encoding="utf-8")
+
+    linter = PyLinter()
+    reporter = Reporter()
+    linter.set_reporter(reporter)
+    checker = similar.SimilarChecker(linter)
+    linter.register_checker(checker)
+    linter.load_configuration()
+    checker.config.min_similarity_lines = 0
+
+    linter.check([str(file1), str(file2)])
+
+    assert not reporter.messages

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(pylint/checkers/similar\.py)' -m pytest --no-header -rA  -p no:cacheprovider tests/checkers/test_min_similarity_lines_zero.py
cat coverage.cover
git checkout 40cc2ffd7887959157aaf469e09585ec2be7f528
git apply /root/pre_state.patch
