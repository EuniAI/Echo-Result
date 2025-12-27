#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 71db08c05197545944949d5aa76cd340e7143627 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 71db08c05197545944949d5aa76cd340e7143627
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/util/rst.py b/sphinx/util/rst.py
--- a/sphinx/util/rst.py
+++ b/sphinx/util/rst.py
@@ -10,22 +10,17 @@
 
 from docutils.parsers.rst import roles
 from docutils.parsers.rst.languages import en as english
+from docutils.parsers.rst.states import Body
 from docutils.statemachine import StringList
 from docutils.utils import Reporter
-from jinja2 import Environment
+from jinja2 import Environment, pass_environment
 
 from sphinx.locale import __
 from sphinx.util import docutils, logging
 
-try:
-    from jinja2.utils import pass_environment
-except ImportError:
-    from jinja2 import environmentfilter as pass_environment
-
-
 logger = logging.getLogger(__name__)
 
-docinfo_re = re.compile(':\\w+:.*?')
+FIELD_NAME_RE = re.compile(Body.patterns['field_marker'])
 symbols_re = re.compile(r'([!-\-/:-@\[-`{-~])')  # symbols without dot(0x2e)
 SECTIONING_CHARS = ['=', '-', '~']
 
@@ -80,7 +75,7 @@ def prepend_prolog(content: StringList, prolog: str) -> None:
     if prolog:
         pos = 0
         for line in content:
-            if docinfo_re.match(line):
+            if FIELD_NAME_RE.match(line):
                 pos += 1
             else:
                 break
@@ -91,6 +86,7 @@ def prepend_prolog(content: StringList, prolog: str) -> None:
             pos += 1
 
         # insert prolog (after docinfo if exists)
+        lineno = 0
         for lineno, line in enumerate(prolog.splitlines()):
             content.insert(pos + lineno, line, '<rst_prolog>', lineno)
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_environment_adapters_toctree.py b/tests/test_environment_adapters_toctree.py
new file mode 100644
index 000000000..096ed83b1
--- /dev/null
+++ b/tests/test_environment_adapters_toctree.py
@@ -0,0 +1,412 @@
+import pytest
+from docutils import nodes
+from docutils.nodes import bullet_list, comment, list_item, literal, reference, title
+
+from sphinx import addnodes
+from sphinx.addnodes import compact_paragraph, only
+from sphinx.builders.html import StandaloneHTMLBuilder
+from sphinx.environment.adapters.toctree import TocTree
+from sphinx.testing.util import assert_node
+
+
+@pytest.mark.sphinx('xml', testroot='toctree')
+@pytest.mark.test_params(shared_result='test_environment_toctree_basic')
+def test_process_doc(app):
+    app.build()
+    # tocs
+    toctree = app.env.tocs['index']
+    assert_node(toctree,
+                [bullet_list, ([list_item, (compact_paragraph,  # [0][0]
+                                            [bullet_list, (addnodes.toctree,  # [0][1][0]
+                                                           only,  # [0][1][1]
+                                                           list_item)])],  # [0][1][2]
+                               [list_item, (compact_paragraph,  # [1][0]
+                                            [bullet_list, (addnodes.toctree,  # [1][1][0]
+                                                           addnodes.toctree)])],  # [1][1][1]
+                               list_item)])
+
+    assert_node(toctree[0][0],
+                [compact_paragraph, reference, "Welcome to Sphinx Tests’s documentation!"])
+    assert_node(toctree[0][0][0], reference, anchorname='')
+    assert_node(toctree[0][1][0], addnodes.toctree,
+                caption="Table of Contents", glob=False, hidden=False,
+                titlesonly=False, maxdepth=2, numbered=999,
+                entries=[(None, 'foo'), (None, 'bar'), (None, 'http://sphinx-doc.org/'),
+                         (None, 'self')],
+                includefiles=['foo', 'bar'])
+
+    # only branch
+    assert_node(toctree[0][1][1], addnodes.only, expr="html")
+    assert_node(toctree[0][1][1],
+                [only, list_item, ([compact_paragraph, reference, "Section for HTML"],
+                                   [bullet_list, addnodes.toctree])])
+    assert_node(toctree[0][1][1][0][0][0], reference, anchorname='#section-for-html')
+    assert_node(toctree[0][1][1][0][1][0], addnodes.toctree,
+                caption=None, glob=False, hidden=False, entries=[(None, 'baz')],
+                includefiles=['baz'], titlesonly=False, maxdepth=-1, numbered=0)
+    assert_node(toctree[0][1][2],
+                ([compact_paragraph, reference, "subsection"],
+                 [bullet_list, list_item, compact_paragraph, reference, "subsubsection"]))
+
+    assert_node(toctree[1][0],
+                [compact_paragraph, reference, "Test for issue #1157"])
+    assert_node(toctree[1][0][0], reference, anchorname='#test-for-issue-1157')
+    assert_node(toctree[1][1][0], addnodes.toctree,
+                caption=None, entries=[], glob=False, hidden=False,
+                titlesonly=False, maxdepth=-1, numbered=0)
+    assert_node(toctree[1][1][1], addnodes.toctree,
+                caption=None, glob=False, hidden=True,
+                titlesonly=False, maxdepth=-1, numbered=0,
+                entries=[('Latest reference', 'http://sphinx-doc.org/latest/'),
+                         ('Python', 'http://python.org/')])
+
+    assert_node(toctree[2][0],
+                [compact_paragraph, reference, "Indices and tables"])
+
+    # other collections
+    assert app.env.toc_num_entries['index'] == 6
+    assert app.env.toctree_includes['index'] == ['foo', 'bar', 'baz']
+    assert app.env.files_to_rebuild['foo'] == {'index'}
+    assert app.env.files_to_rebuild['bar'] == {'index'}
+    assert app.env.files_to_rebuild['baz'] == {'index'}
+    assert app.env.glob_toctrees == set()
+    assert app.env.numbered_toctrees == {'index'}
+
+    # qux has no section title
+    assert len(app.env.tocs['qux']) == 0
+    assert_node(app.env.tocs['qux'], nodes.bullet_list)
+    assert app.env.toc_num_entries['qux'] == 0
+    assert 'qux' not in app.env.toctree_includes
+
+
+@pytest.mark.sphinx('dummy', testroot='toctree-glob')
+def test_glob(app):
+    includefiles = ['foo', 'bar/index', 'bar/bar_1', 'bar/bar_2',
+                    'bar/bar_3', 'baz', 'qux/index']
+
+    app.build()
+
+    # tocs
+    toctree = app.env.tocs['index']
+    assert_node(toctree,
+                [bullet_list, list_item, (compact_paragraph,  # [0][0]
+                                          [bullet_list, (list_item,  # [0][1][0]
+                                                         list_item)])])  # [0][1][1]
+
+    assert_node(toctree[0][0],
+                [compact_paragraph, reference, "test-toctree-glob"])
+    assert_node(toctree[0][1][0],
+                [list_item, ([compact_paragraph, reference, "normal order"],
+                             [bullet_list, addnodes.toctree])])  # [0][1][0][1][0]
+    assert_node(toctree[0][1][0][1][0], addnodes.toctree, caption=None,
+                glob=True, hidden=False, titlesonly=False,
+                maxdepth=-1, numbered=0, includefiles=includefiles,
+                entries=[(None, 'foo'), (None, 'bar/index'), (None, 'bar/bar_1'),
+                         (None, 'bar/bar_2'), (None, 'bar/bar_3'), (None, 'baz'),
+                         (None, 'qux/index'),
+                         ('hyperref', 'https://sphinx-doc.org/?q=sphinx')])
+    assert_node(toctree[0][1][1],
+                [list_item, ([compact_paragraph, reference, "reversed order"],
+                             [bullet_list, addnodes.toctree])])  # [0][1][1][1][0]
+    assert_node(toctree[0][1][1][1][0], addnodes.toctree, caption=None,
+                glob=True, hidden=False, titlesonly=False,
+                maxdepth=-1, numbered=0, includefiles=list(reversed(includefiles)),
+                entries=[(None, 'qux/index'), (None, 'baz'), (None, 'bar/bar_3'),
+                         (None, 'bar/bar_2'), (None, 'bar/bar_1'), (None, 'bar/index'),
+                         (None, 'foo')])
+
+    # other collections
+    assert app.env.toc_num_entries['index'] == 3
+    assert app.env.toctree_includes['index'] == includefiles + list(reversed(includefiles))
+    for file in includefiles:
+        assert 'index' in app.env.files_to_rebuild[file]
+    assert 'index' in app.env.glob_toctrees
+    assert app.env.numbered_toctrees == set()
+
+
+@pytest.mark.sphinx('dummy', testroot='toctree-domain-objects')
+def test_domain_objects(app):
+    includefiles = ['domains']
+
+    app.build()
+
+    assert app.env.toc_num_entries['index'] == 0
+    assert app.env.toc_num_entries['domains'] == 9
+    assert app.env.toctree_includes['index'] == includefiles
+    for file in includefiles:
+        assert 'index' in app.env.files_to_rebuild[file]
+    assert app.env.glob_toctrees == set()
+    assert app.env.numbered_toctrees == {'index'}
+
+    # tocs
+    toctree = app.env.tocs['domains']
+    assert_node(toctree,
+                [bullet_list, list_item, (compact_paragraph,  # [0][0]
+                                          [bullet_list, (list_item,  # [0][1][0]
+                                                         [list_item,  # [0][1][1]
+                                                          (compact_paragraph,  # [0][1][1][0]
+                                                           [bullet_list, (list_item,  # [0][1][1][1][0]
+                                                                          list_item,
+                                                                          list_item,
+                                                                          list_item)])],  # [0][1][1][1][3]
+                                                         list_item,
+                                                         list_item)])])  # [0][1][1]
+
+    assert_node(toctree[0][0],
+                [compact_paragraph, reference, "test-domain-objects"])
+
+    assert_node(toctree[0][1][0],
+                [list_item, ([compact_paragraph, reference, literal, "world()"])])
+
+    assert_node(toctree[0][1][1][1][3],
+                [list_item, ([compact_paragraph, reference, literal, "HelloWorldPrinter.print()"])])
+
+
+@pytest.mark.sphinx('xml', testroot='toctree')
+@pytest.mark.test_params(shared_result='test_environment_toctree_basic')
+def test_get_toc_for(app):
+    app.build()
+    toctree = TocTree(app.env).get_toc_for('index', app.builder)
+
+    assert_node(toctree,
+                [bullet_list, ([list_item, (compact_paragraph,  # [0][0]
+                                            [bullet_list, (addnodes.toctree,  # [0][1][0]
+                                                           comment,  # [0][1][1]
+                                                           list_item)])],  # [0][1][2]
+                               [list_item, (compact_paragraph,  # [1][0]
+                                            [bullet_list, (addnodes.toctree,
+                                                           addnodes.toctree)])],
+                               [list_item, compact_paragraph])])  # [2][0]
+    assert_node(toctree[0][0],
+                [compact_paragraph, reference, "Welcome to Sphinx Tests’s documentation!"])
+    assert_node(toctree[0][1][2],
+                ([compact_paragraph, reference, "subsection"],
+                 [bullet_list, list_item, compact_paragraph, reference, "subsubsection"]))
+    assert_node(toctree[1][0],
+                [compact_paragraph, reference, "Test for issue #1157"])
+    assert_node(toctree[2][0],
+                [compact_paragraph, reference, "Indices and tables"])
+
+
+@pytest.mark.sphinx('xml', testroot='toctree')
+@pytest.mark.test_params(shared_result='test_environment_toctree_basic')
+def test_get_toc_for_only(app):
+    app.build()
+    builder = StandaloneHTMLBuilder(app, app.env)
+    toctree = TocTree(app.env).get_toc_for('index', builder)
+
+    assert_node(toctree,
+                [bullet_list, ([list_item, (compact_paragraph,  # [0][0]
+                                            [bullet_list, (addnodes.toctree,  # [0][1][0]
+                                                           list_item,  # [0][1][1]
+                                                           list_item)])],  # [0][1][2]
+                               [list_item, (compact_paragraph,  # [1][0]
+                                            [bullet_list, (addnodes.toctree,
+                                                           addnodes.toctree)])],
+                               [list_item, compact_paragraph])])  # [2][0]
+    assert_node(toctree[0][0],
+                [compact_paragraph, reference, "Welcome to Sphinx Tests’s documentation!"])
+    assert_node(toctree[0][1][1],
+                ([compact_paragraph, reference, "Section for HTML"],
+                 [bullet_list, addnodes.toctree]))
+    assert_node(toctree[0][1][2],
+                ([compact_paragraph, reference, "subsection"],
+                 [bullet_list, list_item, compact_paragraph, reference, "subsubsection"]))
+    assert_node(toctree[1][0],
+                [compact_paragraph, reference, "Test for issue #1157"])
+    assert_node(toctree[2][0],
+                [compact_paragraph, reference, "Indices and tables"])
+
+
+@pytest.mark.sphinx('xml', testroot='toctree')
+@pytest.mark.test_params(shared_result='test_environment_toctree_basic')
+def test_get_toc_for_tocdepth(app):
+    app.build()
+    toctree = TocTree(app.env).get_toc_for('tocdepth', app.builder)
+
+    assert_node(toctree,
+                [bullet_list, list_item, (compact_paragraph,  # [0][0]
+                                          bullet_list)])  # [0][1]
+    assert_node(toctree[0][0],
+                [compact_paragraph, reference, "level 1"])
+    assert_node(toctree[0][1],
+                [bullet_list, list_item, compact_paragraph, reference, "level 2"])
+
+
+@pytest.mark.sphinx('xml', testroot='toctree')
+@pytest.mark.test_params(shared_result='test_environment_toctree_basic')
+def test_get_toctree_for(app):
+    app.build()
+    toctree = TocTree(app.env).get_toctree_for('index', app.builder, collapse=False)
+    assert_node(toctree,
+                [compact_paragraph, ([title, "Table of Contents"],
+                                     bullet_list,
+                                     bullet_list,
+                                     bullet_list)])
+
+    assert_node(toctree[1],
+                ([list_item, ([compact_paragraph, reference, "foo"],
+                              bullet_list)],
+                 [list_item, compact_paragraph, reference, "bar"],
+                 [list_item, compact_paragraph, reference, "http://sphinx-doc.org/"],
+                 [list_item, compact_paragraph, reference,
+                  "Welcome to Sphinx Tests’s documentation!"]))
+    assert_node(toctree[1][0][1],
+                ([list_item, compact_paragraph, reference, "quux"],
+                 [list_item, compact_paragraph, reference, "foo.1"],
+                 [list_item, compact_paragraph, reference, "foo.2"]))
+
+    assert_node(toctree[1][0][0][0], reference, refuri="foo", secnumber=[1])
+    assert_node(toctree[1][0][1][0][0][0], reference, refuri="quux", secnumber=[1, 1])
+    assert_node(toctree[1][0][1][1][0][0], reference, refuri="foo#foo-1", secnumber=[1, 2])
+    assert_node(toctree[1][0][1][2][0][0], reference, refuri="foo#foo-2", secnumber=[1, 3])
+    assert_node(toctree[1][1][0][0], reference, refuri="bar", secnumber=[2])
+    assert_node(toctree[1][2][0][0], reference, refuri="http://sphinx-doc.org/")
+    assert_node(toctree[1][3][0][0], reference, refuri="")
+
+    assert_node(toctree[2],
+                [bullet_list, list_item, compact_paragraph, reference, "baz"])
+    assert_node(toctree[3],
+                ([list_item, compact_paragraph, reference, "Latest reference"],
+                 [list_item, compact_paragraph, reference, "Python"]))
+    assert_node(toctree[3][0][0][0], reference, refuri="http://sphinx-doc.org/latest/")
+    assert_node(toctree[3][1][0][0], reference, refuri="http://python.org/")
+
+
+@pytest.mark.sphinx('xml', testroot='toctree')
+@pytest.mark.test_params(shared_result='test_environment_toctree_basic')
+def test_get_toctree_for_collapse(app):
+    app.build()
+    toctree = TocTree(app.env).get_toctree_for('index', app.builder, collapse=True)
+    assert_node(toctree,
+                [compact_paragraph, ([title, "Table of Contents"],
+                                     bullet_list,
+                                     bullet_list,
+                                     bullet_list)])
+
+    assert_node(toctree[1],
+                ([list_item, compact_paragraph, reference, "foo"],
+                 [list_item, compact_paragraph, reference, "bar"],
+                 [list_item, compact_paragraph, reference, "http://sphinx-doc.org/"],
+                 [list_item, compact_paragraph, reference,
+                  "Welcome to Sphinx Tests’s documentation!"]))
+    assert_node(toctree[1][0][0][0], reference, refuri="foo", secnumber=[1])
+    assert_node(toctree[1][1][0][0], reference, refuri="bar", secnumber=[2])
+    assert_node(toctree[1][2][0][0], reference, refuri="http://sphinx-doc.org/")
+    assert_node(toctree[1][3][0][0], reference, refuri="")
+
+    assert_node(toctree[2],
+                [bullet_list, list_item, compact_paragraph, reference, "baz"])
+    assert_node(toctree[3],
+                ([list_item, compact_paragraph, reference, "Latest reference"],
+                 [list_item, compact_paragraph, reference, "Python"]))
+    assert_node(toctree[3][0][0][0], reference, refuri="http://sphinx-doc.org/latest/")
+    assert_node(toctree[3][1][0][0], reference, refuri="http://python.org/")
+
+
+@pytest.mark.sphinx('xml', testroot='toctree')
+@pytest.mark.test_params(shared_result='test_environment_toctree_basic')
+def test_get_toctree_for_maxdepth(app):
+    app.build()
+    toctree = TocTree(app.env).get_toctree_for('index', app.builder,
+                                               collapse=False, maxdepth=3)
+    assert_node(toctree,
+                [compact_paragraph, ([title, "Table of Contents"],
+                                     bullet_list,
+                                     bullet_list,
+                                     bullet_list)])
+
+    assert_node(toctree[1],
+                ([list_item, ([compact_paragraph, reference, "foo"],
+                              bullet_list)],
+                 [list_item, compact_paragraph, reference, "bar"],
+                 [list_item, compact_paragraph, reference, "http://sphinx-doc.org/"],
+                 [list_item, compact_paragraph, reference,
+                  "Welcome to Sphinx Tests’s documentation!"]))
+    assert_node(toctree[1][0][1],
+                ([list_item, compact_paragraph, reference, "quux"],
+                 [list_item, ([compact_paragraph, reference, "foo.1"],
+                              bullet_list)],
+                 [list_item, compact_paragraph, reference, "foo.2"]))
+    assert_node(toctree[1][0][1][1][1],
+                [bullet_list, list_item, compact_paragraph, reference, "foo.1-1"])
+
+    assert_node(toctree[1][0][0][0], reference, refuri="foo", secnumber=[1])
+    assert_node(toctree[1][0][1][0][0][0], reference, refuri="quux", secnumber=[1, 1])
+    assert_node(toctree[1][0][1][1][0][0], reference, refuri="foo#foo-1", secnumber=[1, 2])
+    assert_node(toctree[1][0][1][1][1][0][0][0],
+                reference, refuri="foo#foo-1-1", secnumber=[1, 2, 1])
+    assert_node(toctree[1][0][1][2][0][0], reference, refuri="foo#foo-2", secnumber=[1, 3])
+    assert_node(toctree[1][1][0][0], reference, refuri="bar", secnumber=[2])
+    assert_node(toctree[1][2][0][0], reference, refuri="http://sphinx-doc.org/")
+    assert_node(toctree[1][3][0][0], reference, refuri="")
+
+    assert_node(toctree[2],
+                [bullet_list, list_item, compact_paragraph, reference, "baz"])
+    assert_node(toctree[3],
+                ([list_item, compact_paragraph, reference, "Latest reference"],
+                 [list_item, compact_paragraph, reference, "Python"]))
+    assert_node(toctree[3][0][0][0], reference, refuri="http://sphinx-doc.org/latest/")
+    assert_node(toctree[3][1][0][0], reference, refuri="http://python.org/")
+
+
+@pytest.mark.sphinx('xml', testroot='toctree')
+@pytest.mark.test_params(shared_result='test_environment_toctree_basic')
+def test_get_toctree_for_includehidden(app):
+    app.build()
+    toctree = TocTree(app.env).get_toctree_for('index', app.builder, collapse=False,
+                                               includehidden=False)
+    assert_node(toctree,
+                [compact_paragraph, ([title, "Table of Contents"],
+                                     bullet_list,
+                                     bullet_list)])
+
+    assert_node(toctree[1],
+                ([list_item, ([compact_paragraph, reference, "foo"],
+                              bullet_list)],
+                 [list_item, compact_paragraph, reference, "bar"],
+                 [list_item, compact_paragraph, reference, "http://sphinx-doc.org/"],
+                 [list_item, compact_paragraph, reference,
+                  "Welcome to Sphinx Tests’s documentation!"]))
+    assert_node(toctree[1][0][1],
+                ([list_item, compact_paragraph, reference, "quux"],
+                 [list_item, compact_paragraph, reference, "foo.1"],
+                 [list_item, compact_paragraph, reference, "foo.2"]))
+
+    assert_node(toctree[1][0][0][0], reference, refuri="foo", secnumber=[1])
+    assert_node(toctree[1][0][1][0][0][0], reference, refuri="quux", secnumber=[1, 1])
+    assert_node(toctree[1][0][1][1][0][0], reference, refuri="foo#foo-1", secnumber=[1, 2])
+    assert_node(toctree[1][0][1][2][0][0], reference, refuri="foo#foo-2", secnumber=[1, 3])
+    assert_node(toctree[1][1][0][0], reference, refuri="bar", secnumber=[2])
+    assert_node(toctree[1][2][0][0], reference, refuri="http://sphinx-doc.org/")
+
+    assert_node(toctree[2],
+                [bullet_list, list_item, compact_paragraph, reference, "baz"])
+
+
+@pytest.mark.sphinx('xml', testroot='toctree-index')
+def test_toctree_index(app):
+    app.build()
+    toctree = app.env.tocs['index']
+    assert_node(toctree,
+                [bullet_list, ([list_item, (compact_paragraph,  # [0][0]
+                                            [bullet_list, (addnodes.toctree,  # [0][1][0]
+                                                           addnodes.toctree)])])])  # [0][1][1]
+    assert_node(toctree[0][1][1], addnodes.toctree,
+                caption="Indices", glob=False, hidden=False,
+                titlesonly=False, maxdepth=-1, numbered=0,
+                entries=[(None, 'genindex'), (None, 'modindex'), (None, 'search')])
+
+
+@pytest.mark.sphinx(
+    'html',
+    confoverrides={'rst_prolog': '.. |foo| replace:: bar'}
+)
+def test_rst_prolog_with_domain_directive_heading(app):
+    """Test that a domain directive in a heading is not lost when rst_prolog is used."""
+    (app.srcdir / 'index.rst').write_text('.. toctree::\n\n   mypackage\n')
+    (app.srcdir / 'mypackage.rst').write_text(':mod:`mypackage`\n=================\n\nContent\n')
+    app.build()
+
+    toc = app.env.tocs['mypackage']
+    assert len(toc) == 1

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/util/rst\.py)' -m tox -epy39 -v -- tests/test_environment_adapters_toctree.py
cat coverage.cover
git checkout 71db08c05197545944949d5aa76cd340e7143627
git apply /root/pre_state.patch
