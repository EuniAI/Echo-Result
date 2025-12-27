#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 2e506c5ab457cba743bb47eb5b8c8eb9dd51d23d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 2e506c5ab457cba743bb47eb5b8c8eb9dd51d23d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_domain_cpp_user_defined_literals.py b/tests/test_domain_cpp_user_defined_literals.py
new file mode 100644
index 000000000..eab0600a9
--- /dev/null
+++ b/tests/test_domain_cpp_user_defined_literals.py
@@ -0,0 +1,89 @@
+import re
+
+import pytest
+
+from sphinx import addnodes
+from sphinx.domains.cpp import DefinitionParser, DefinitionError, NoOldIdError
+from sphinx.domains.cpp import Symbol, _max_id, _id_prefix
+
+
+def parse(name, string):
+    class Config:
+        cpp_id_attributes = ["id_attr"]
+        cpp_paren_attributes = ["paren_attr"]
+    parser = DefinitionParser(string, location=None, config=Config())
+    parser.allowFallbackExpressionParsing = False
+    ast = parser.parse_declaration(name, name)
+    parser.assert_end()
+    # The scopedness would usually have been set by CPPEnumObject
+    if name == "enum":
+        ast.scoped = None  # simulate unscoped enum
+    return ast
+
+
+def _check(name, input, idDict, output):
+    # first a simple check of the AST
+    ast = parse(name, input)
+    res = str(ast)
+    if res != output:
+        print("")
+        print("Input:    ", input)
+        print("Result:   ", res)
+        print("Expected: ", output)
+        raise DefinitionError("")
+    rootSymbol = Symbol(None, None, None, None, None, None)
+    symbol = rootSymbol.add_declaration(ast, docname="TestDoc")
+    parentNode = addnodes.desc()
+    signode = addnodes.desc_signature(input, '')
+    parentNode += signode
+    ast.describe_signature(signode, 'lastIsName', symbol, options={})
+
+    idExpected = [None]
+    for i in range(1, _max_id + 1):
+        if i in idDict:
+            idExpected.append(idDict[i])
+        else:
+            idExpected.append(idExpected[i - 1])
+    idActual = [None]
+    for i in range(1, _max_id + 1):
+        try:
+            id = ast.get_id(version=i)
+            assert id is not None
+            idActual.append(id[len(_id_prefix[i]):])
+        except NoOldIdError:
+            idActual.append(None)
+
+    res = [True]
+    for i in range(1, _max_id + 1):
+        res.append(idExpected[i] == idActual[i])
+
+    if not all(res):
+        print("input:    %s" % input.rjust(20))
+        for i in range(1, _max_id + 1):
+            if res[i]:
+                continue
+            print("Error in id version %d." % i)
+            print("result:   %s" % idActual[i])
+            print("expected: %s" % idExpected[i])
+        print(rootSymbol.dump(0))
+        raise DefinitionError("")
+
+
+def check(name, input, idDict, output=None):
+    if output is None:
+        output = input
+    # First, check without semicolon
+    _check(name, input, idDict, output)
+    # Second, check with semicolon
+    _check(name, input + ' ;', idDict, output + ';')
+
+
+def test_user_defined_literal_in_variable_declaration():
+    """Tests parsing of a variable declaration with user-defined literals.
+
+    This was not supported and caused a parsing error.
+    """
+    check('member',
+          'constexpr auto planck_constant = 6.62607015e-34q_J * 1q_s',
+          {1: 'planck_constant__auto', 2: '17planck_constant'},
+          'constexpr auto planck_constant = 6.62607015e-34q_J * 1q_s')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/domains/c\.py|sphinx/domains/cpp\.py|sphinx/util/cfamily\.py)' -m tox -epy39 -v -- tests/test_domain_cpp_user_defined_literals.py
cat coverage.cover
git checkout 2e506c5ab457cba743bb47eb5b8c8eb9dd51d23d
git apply /root/pre_state.patch
