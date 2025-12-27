#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c50643a49811e9fe2f4851adff4313ad46f7325e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c50643a49811e9fe2f4851adff4313ad46f7325e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/sympy/crypto/tests/test_morse_code.py b/sympy/crypto/tests/test_morse_code.py
new file mode 100644
index 0000000000..4903f826a6
--- /dev/null
+++ b/sympy/crypto/tests/test_morse_code.py
@@ -0,0 +1,11 @@
+from sympy.crypto.crypto import encode_morse
+
+
+def test_morse_code_for_1():
+    """
+    Tests the morse encoding for the digit "1".
+
+    The correct encoding is ".----", but a bug in the mapping
+    caused it to be "----".
+    """
+    assert encode_morse("1") == ".----"

EOF_114329324912
PYTHONWARNINGS='ignore::UserWarning,ignore::SyntaxWarning' python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sympy/crypto/crypto\.py)' bin/test -C --verbose sympy/crypto/tests/test_morse_code.p
cat coverage.cover
git checkout c50643a49811e9fe2f4851adff4313ad46f7325e
git apply /root/pre_state.patch
