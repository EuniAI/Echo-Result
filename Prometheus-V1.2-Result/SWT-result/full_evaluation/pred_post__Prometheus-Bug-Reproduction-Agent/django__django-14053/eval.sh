#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 179ee13eb37348cd87169a198aec18fedccc8668 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 179ee13eb37348cd87169a198aec18fedccc8668
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/staticfiles/storage.py b/django/contrib/staticfiles/storage.py
--- a/django/contrib/staticfiles/storage.py
+++ b/django/contrib/staticfiles/storage.py
@@ -226,17 +226,25 @@ def post_process(self, paths, dry_run=False, **options):
             path for path in paths
             if matches_patterns(path, self._patterns)
         ]
-        # Do a single pass first. Post-process all files once, then repeat for
-        # adjustable files.
+
+        # Adjustable files to yield at end, keyed by the original path.
+        processed_adjustable_paths = {}
+
+        # Do a single pass first. Post-process all files once, yielding not
+        # adjustable files and exceptions, and collecting adjustable files.
         for name, hashed_name, processed, _ in self._post_process(paths, adjustable_paths, hashed_files):
-            yield name, hashed_name, processed
+            if name not in adjustable_paths or isinstance(processed, Exception):
+                yield name, hashed_name, processed
+            else:
+                processed_adjustable_paths[name] = (name, hashed_name, processed)
 
         paths = {path: paths[path] for path in adjustable_paths}
 
         for i in range(self.max_post_process_passes):
             substitutions = False
             for name, hashed_name, processed, subst in self._post_process(paths, adjustable_paths, hashed_files):
-                yield name, hashed_name, processed
+                # Overwrite since hashed_name may be newer.
+                processed_adjustable_paths[name] = (name, hashed_name, processed)
                 substitutions = substitutions or subst
 
             if not substitutions:
@@ -248,6 +256,9 @@ def post_process(self, paths, dry_run=False, **options):
         # Store the processed paths
         self.hashed_files.update(hashed_files)
 
+        # Yield adjustable files with final, hashed name.
+        yield from processed_adjustable_paths.values()
+
     def _post_process(self, paths, adjustable_paths, hashed_files):
         # Sort the files by directory level
         def path_level(name):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/staticfiles_tests/test_hashed_storage.py b/tests/staticfiles_tests/test_hashed_storage.py
new file mode 100644
index 0000000000..2d14acda9d
--- /dev/null
+++ b/tests/staticfiles_tests/test_hashed_storage.py
@@ -0,0 +1,541 @@
+import os
+import shutil
+import sys
+import tempfile
+import unittest
+from io import StringIO
+from pathlib import Path
+from unittest import mock
+
+from django.conf import settings
+from django.contrib.staticfiles import finders, storage
+from django.contrib.staticfiles.management.commands.collectstatic import (
+    Command as CollectstaticCommand,
+)
+from django.core.management import call_command
+from django.test import override_settings
+
+from .cases import CollectionTestCase
+from .settings import TEST_ROOT
+
+
+def hashed_file_path(test, path):
+    fullpath = test.render_template(test.static_template_snippet(path))
+    return fullpath.replace(settings.STATIC_URL, '')
+
+
+class TestHashedFiles:
+    hashed_file_path = hashed_file_path
+
+    def setUp(self):
+        self._max_post_process_passes = storage.staticfiles_storage.max_post_process_passes
+        super().setUp()
+
+    def tearDown(self):
+        # Clear hashed files to avoid side effects among tests.
+        storage.staticfiles_storage.hashed_files.clear()
+        storage.staticfiles_storage.max_post_process_passes = self._max_post_process_passes
+
+    def assertPostCondition(self):
+        """
+        Assert post conditions for a test are met. Must be manually called at
+        the end of each test.
+        """
+        pass
+
+    def test_template_tag_return(self):
+        self.assertStaticRaises(ValueError, "does/not/exist.png", "/static/does/not/exist.png")
+        self.assertStaticRenders("test/file.txt", "/static/test/file.dad0999e4f8f.txt")
+        self.assertStaticRenders("test/file.txt", "/static/test/file.dad0999e4f8f.txt", asvar=True)
+        self.assertStaticRenders("cached/styles.css", "/static/cached/styles.5e0040571e1a.css")
+        self.assertStaticRenders("path/", "/static/path/")
+        self.assertStaticRenders("path/?query", "/static/path/?query")
+        self.assertPostCondition()
+
+    def test_template_tag_simple_content(self):
+        relpath = self.hashed_file_path("cached/styles.css")
+        self.assertEqual(relpath, "cached/styles.5e0040571e1a.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            content = relfile.read()
+            self.assertNotIn(b"cached/other.css", content)
+            self.assertIn(b"other.d41d8cd98f00.css", content)
+        self.assertPostCondition()
+
+    def test_path_ignored_completely(self):
+        relpath = self.hashed_file_path("cached/css/ignored.css")
+        self.assertEqual(relpath, "cached/css/ignored.554da52152af.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            content = relfile.read()
+            self.assertIn(b'#foobar', content)
+            self.assertIn(b'http:foobar', content)
+            self.assertIn(b'https:foobar', content)
+            self.assertIn(b'data:foobar', content)
+            self.assertIn(b'chrome:foobar', content)
+            self.assertIn(b'//foobar', content)
+        self.assertPostCondition()
+
+    def test_path_with_querystring(self):
+        relpath = self.hashed_file_path("cached/styles.css?spam=eggs")
+        self.assertEqual(relpath, "cached/styles.5e0040571e1a.css?spam=eggs")
+        with storage.staticfiles_storage.open("cached/styles.5e0040571e1a.css") as relfile:
+            content = relfile.read()
+            self.assertNotIn(b"cached/other.css", content)
+            self.assertIn(b"other.d41d8cd98f00.css", content)
+        self.assertPostCondition()
+
+    def test_path_with_fragment(self):
+        relpath = self.hashed_file_path("cached/styles.css#eggs")
+        self.assertEqual(relpath, "cached/styles.5e0040571e1a.css#eggs")
+        with storage.staticfiles_storage.open("cached/styles.5e0040571e1a.css") as relfile:
+            content = relfile.read()
+            self.assertNotIn(b"cached/other.css", content)
+            self.assertIn(b"other.d41d8cd98f00.css", content)
+        self.assertPostCondition()
+
+    def test_path_with_querystring_and_fragment(self):
+        relpath = self.hashed_file_path("cached/css/fragments.css")
+        self.assertEqual(relpath, "cached/css/fragments.a60c0e74834f.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            content = relfile.read()
+            self.assertIn(b'fonts/font.b9b105392eb8.eot?#iefix', content)
+            self.assertIn(b'fonts/font.b8d603e42714.svg#webfontIyfZbseF', content)
+            self.assertIn(b'fonts/font.b8d603e42714.svg#path/to/../../fonts/font.svg', content)
+            self.assertIn(b'data:font/woff;charset=utf-8;base64,d09GRgABAAAAADJoAA0AAAAAR2QAAQAAAAAAAAAAAAA', content)
+            self.assertIn(b'#default#VML', content)
+        self.assertPostCondition()
+
+    def test_template_tag_absolute(self):
+        relpath = self.hashed_file_path("cached/absolute.css")
+        self.assertEqual(relpath, "cached/absolute.eb04def9f9a4.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            content = relfile.read()
+            self.assertNotIn(b"/static/cached/styles.css", content)
+            self.assertIn(b"/static/cached/styles.5e0040571e1a.css", content)
+            self.assertNotIn(b"/static/styles_root.css", content)
+            self.assertIn(b"/static/styles_root.401f2509a628.css", content)
+            self.assertIn(b'/static/cached/img/relative.acae32e4532b.png', content)
+        self.assertPostCondition()
+
+    def test_template_tag_absolute_root(self):
+        """
+        Like test_template_tag_absolute, but for a file in STATIC_ROOT (#26249).
+        """
+        relpath = self.hashed_file_path("absolute_root.css")
+        self.assertEqual(relpath, "absolute_root.f821df1b64f7.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            content = relfile.read()
+            self.assertNotIn(b"/static/styles_root.css", content)
+            self.assertIn(b"/static/styles_root.401f2509a628.css", content)
+        self.assertPostCondition()
+
+    def test_template_tag_relative(self):
+        relpath = self.hashed_file_path("cached/relative.css")
+        self.assertEqual(relpath, "cached/relative.c3e9e1ea6f2e.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            content = relfile.read()
+            self.assertNotIn(b"../cached/styles.css", content)
+            self.assertNotIn(b'@import "styles.css"', content)
+            self.assertNotIn(b'url(img/relative.png)', content)
+            self.assertIn(b'url("img/relative.acae32e4532b.png")', content)
+            self.assertIn(b"../cached/styles.5e0040571e1a.css", content)
+        self.assertPostCondition()
+
+    def test_import_replacement(self):
+        "See #18050"
+        relpath = self.hashed_file_path("cached/import.css")
+        self.assertEqual(relpath, "cached/import.f53576679e5a.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            self.assertIn(b'import url("styles.5e0040571e1a.css")', relfile.read())
+        self.assertPostCondition()
+
+    def test_template_tag_deep_relative(self):
+        relpath = self.hashed_file_path("cached/css/window.css")
+        self.assertEqual(relpath, "cached/css/window.5d5c10836967.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            content = relfile.read()
+            self.assertNotIn(b'url(img/window.png)', content)
+            self.assertIn(b'url("img/window.acae32e4532b.png")', content)
+        self.assertPostCondition()
+
+    def test_template_tag_url(self):
+        relpath = self.hashed_file_path("cached/url.css")
+        self.assertEqual(relpath, "cached/url.902310b73412.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            self.assertIn(b"https://", relfile.read())
+        self.assertPostCondition()
+
+    @override_settings(
+        STATICFILES_DIRS=[os.path.join(TEST_ROOT, 'project', 'loop')],
+        STATICFILES_FINDERS=['django.contrib.staticfiles.finders.FileSystemFinder'],
+    )
+    def test_import_loop(self):
+        finders.get_finder.cache_clear()
+        err = StringIO()
+        with self.assertRaisesMessage(RuntimeError, 'Max post-process passes exceeded'):
+            call_command('collectstatic', interactive=False, verbosity=0, stderr=err)
+        self.assertEqual("Post-processing 'All' failed!\n\n", err.getvalue())
+        self.assertPostCondition()
+
+    def test_post_processing(self):
+        """
+        post_processing behaves correctly.
+
+        Files that are alterable should always be post-processed; files that
+        aren't should be skipped.
+
+        collectstatic has already been called once in setUp() for this testcase,
+        therefore we check by verifying behavior on a second run.
+        """
+        collectstatic_args = {
+            'interactive': False,
+            'verbosity': 0,
+            'link': False,
+            'clear': False,
+            'dry_run': False,
+            'post_process': True,
+            'use_default_ignore_patterns': True,
+            'ignore_patterns': ['*.ignoreme'],
+        }
+
+        collectstatic_cmd = CollectstaticCommand()
+        collectstatic_cmd.set_options(**collectstatic_args)
+        stats = collectstatic_cmd.collect()
+        self.assertIn(os.path.join('cached', 'css', 'window.css'), stats['post_processed'])
+        self.assertIn(os.path.join('cached', 'css', 'img', 'window.png'), stats['unmodified'])
+        self.assertIn(os.path.join('test', 'nonascii.css'), stats['post_processed'])
+        self.assertPostCondition()
+
+    def test_css_import_case_insensitive(self):
+        relpath = self.hashed_file_path("cached/styles_insensitive.css")
+        self.assertEqual(relpath, "cached/styles_insensitive.3fa427592a53.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            content = relfile.read()
+            self.assertNotIn(b"cached/other.css", content)
+            self.assertIn(b"other.d41d8cd98f00.css", content)
+        self.assertPostCondition()
+
+    @override_settings(
+        STATICFILES_DIRS=[os.path.join(TEST_ROOT, 'project', 'faulty')],
+        STATICFILES_FINDERS=['django.contrib.staticfiles.finders.FileSystemFinder'],
+    )
+    def test_post_processing_failure(self):
+        """
+        post_processing indicates the origin of the error when it fails.
+        """
+        finders.get_finder.cache_clear()
+        err = StringIO()
+        with self.assertRaises(Exception):
+            call_command('collectstatic', interactive=False, verbosity=0, stderr=err)
+        self.assertEqual("Post-processing 'faulty.css' failed!\n\n", err.getvalue())
+        self.assertPostCondition()
+
+
+@override_settings(STATICFILES_STORAGE='staticfiles_tests.storage.ExtraPatternsStorage')
+class TestExtraPatternsStorage(CollectionTestCase):
+
+    def setUp(self):
+        storage.staticfiles_storage.hashed_files.clear()  # avoid cache interference
+        super().setUp()
+
+    def cached_file_path(self, path):
+        fullpath = self.render_template(self.static_template_snippet(path))
+        return fullpath.replace(settings.STATIC_URL, '')
+
+    def test_multi_extension_patterns(self):
+        """
+        With storage classes having several file extension patterns, only the
+        files matching a specific file pattern should be affected by the
+        substitution (#19670).
+        """
+        # CSS files shouldn't be touched by JS patterns.
+        relpath = self.cached_file_path("cached/import.css")
+        self.assertEqual(relpath, "cached/import.f53576679e5a.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            self.assertIn(b'import url("styles.5e0040571e1a.css")', relfile.read())
+
+        # Confirm JS patterns have been applied to JS files.
+        relpath = self.cached_file_path("cached/test.js")
+        self.assertEqual(relpath, "cached/test.388d7a790d46.js")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            self.assertIn(b'JS_URL("import.f53576679e5a.css")', relfile.read())
+
+
+@override_settings(
+    STATICFILES_STORAGE='django.contrib.staticfiles.storage.ManifestStaticFilesStorage',
+)
+class TestCollectionManifestStorage(TestHashedFiles, CollectionTestCase):
+    """
+    Tests for the Cache busting storage
+    """
+    def setUp(self):
+        super().setUp()
+
+        temp_dir = tempfile.mkdtemp()
+        os.makedirs(os.path.join(temp_dir, 'test'))
+        self._clear_filename = os.path.join(temp_dir, 'test', 'cleared.txt')
+        with open(self._clear_filename, 'w') as f:
+            f.write('to be deleted in one test')
+
+        self.patched_settings = self.settings(
+            STATICFILES_DIRS=settings.STATICFILES_DIRS + [temp_dir],
+        )
+        self.patched_settings.enable()
+        self.addCleanup(shutil.rmtree, temp_dir)
+        self._manifest_strict = storage.staticfiles_storage.manifest_strict
+
+    def tearDown(self):
+        self.patched_settings.disable()
+
+        if os.path.exists(self._clear_filename):
+            os.unlink(self._clear_filename)
+
+        storage.staticfiles_storage.manifest_strict = self._manifest_strict
+        super().tearDown()
+
+    def assertPostCondition(self):
+        hashed_files = storage.staticfiles_storage.hashed_files
+        # The in-memory version of the manifest matches the one on disk
+        # since a properly created manifest should cover all filenames.
+        if hashed_files:
+            manifest = storage.staticfiles_storage.load_manifest()
+            self.assertEqual(hashed_files, manifest)
+
+    def test_manifest_exists(self):
+        filename = storage.staticfiles_storage.manifest_name
+        path = storage.staticfiles_storage.path(filename)
+        self.assertTrue(os.path.exists(path))
+
+    def test_manifest_does_not_exist(self):
+        storage.staticfiles_storage.manifest_name = 'does.not.exist.json'
+        self.assertIsNone(storage.staticfiles_storage.read_manifest())
+
+    def test_manifest_does_not_ignore_permission_error(self):
+        with mock.patch('builtins.open', side_effect=PermissionError):
+            with self.assertRaises(PermissionError):
+                storage.staticfiles_storage.read_manifest()
+
+    def test_loaded_cache(self):
+        self.assertNotEqual(storage.staticfiles_storage.hashed_files, {})
+        manifest_content = storage.staticfiles_storage.read_manifest()
+        self.assertIn(
+            '"version": "%s"' % storage.staticfiles_storage.manifest_version,
+            manifest_content
+        )
+
+    def test_parse_cache(self):
+        hashed_files = storage.staticfiles_storage.hashed_files
+        manifest = storage.staticfiles_storage.load_manifest()
+        self.assertEqual(hashed_files, manifest)
+
+    def test_clear_empties_manifest(self):
+        cleared_file_name = storage.staticfiles_storage.clean_name(os.path.join('test', 'cleared.txt'))
+        # collect the additional file
+        self.run_collectstatic()
+
+        hashed_files = storage.staticfiles_storage.hashed_files
+        self.assertIn(cleared_file_name, hashed_files)
+
+        manifest_content = storage.staticfiles_storage.load_manifest()
+        self.assertIn(cleared_file_name, manifest_content)
+
+        original_path = storage.staticfiles_storage.path(cleared_file_name)
+        self.assertTrue(os.path.exists(original_path))
+
+        # delete the original file form the app, collect with clear
+        os.unlink(self._clear_filename)
+        self.run_collectstatic(clear=True)
+
+        self.assertFileNotFound(original_path)
+
+        hashed_files = storage.staticfiles_storage.hashed_files
+        self.assertNotIn(cleared_file_name, hashed_files)
+
+        manifest_content = storage.staticfiles_storage.load_manifest()
+        self.assertNotIn(cleared_file_name, manifest_content)
+
+    def test_missing_entry(self):
+        missing_file_name = 'cached/missing.css'
+        configured_storage = storage.staticfiles_storage
+        self.assertNotIn(missing_file_name, configured_storage.hashed_files)
+
+        # File name not found in manifest
+        with self.assertRaisesMessage(ValueError, "Missing staticfiles manifest entry for '%s'" % missing_file_name):
+            self.hashed_file_path(missing_file_name)
+
+        configured_storage.manifest_strict = False
+        # File doesn't exist on disk
+        err_msg = "The file '%s' could not be found with %r." % (missing_file_name, configured_storage._wrapped)
+        with self.assertRaisesMessage(ValueError, err_msg):
+            self.hashed_file_path(missing_file_name)
+
+        content = StringIO()
+        content.write('Found')
+        configured_storage.save(missing_file_name, content)
+        # File exists on disk
+        self.hashed_file_path(missing_file_name)
+
+    def test_intermediate_files(self):
+        cached_files = os.listdir(os.path.join(settings.STATIC_ROOT, 'cached'))
+        # Intermediate files shouldn't be created for reference.
+        self.assertEqual(
+            len([
+                cached_file
+                for cached_file in cached_files
+                if cached_file.startswith('relative.')
+            ]),
+            2,
+        )
+
+    def test_post_process_yields_each_file_only_once(self):
+        """
+        HashedFilesMixin.post_process() should not yield the same file multiple
+        times.
+        """
+        # The base setup runs collectstatic once, but to get the stats back
+        # from the command, we run it again.
+        collectstatic_cmd = CollectstaticCommand()
+        # The options are based on the existing test_post_processing test.
+        collectstatic_cmd.set_options(
+            interactive=False,
+            verbosity=0,
+            link=False,
+            clear=False,
+            dry_run=False,
+            post_process=True,
+            use_default_ignore_patterns=True,
+            ignore_patterns=['*.ignoreme'],
+        )
+        stats = collectstatic_cmd.collect()
+        post_processed_files = stats['post_processed']
+        self.assertEqual(
+            len(post_processed_files),
+            len(set(post_processed_files)),
+            "post_process() yielded some files more than once."
+        )
+
+
+@override_settings(STATICFILES_STORAGE='staticfiles_tests.storage.NoneHashStorage')
+class TestCollectionNoneHashStorage(CollectionTestCase):
+    hashed_file_path = hashed_file_path
+
+    def test_hashed_name(self):
+        relpath = self.hashed_file_path('cached/styles.css')
+        self.assertEqual(relpath, 'cached/styles.css')
+
+
+@override_settings(STATICFILES_STORAGE='staticfiles_tests.storage.SimpleStorage')
+class TestCollectionSimpleStorage(CollectionTestCase):
+    hashed_file_path = hashed_file_path
+
+    def setUp(self):
+        storage.staticfiles_storage.hashed_files.clear()  # avoid cache interference
+        super().setUp()
+
+    def test_template_tag_return(self):
+        self.assertStaticRaises(ValueError, "does/not/exist.png", "/static/does/not/exist.png")
+        self.assertStaticRenders("test/file.txt", "/static/test/file.deploy12345.txt")
+        self.assertStaticRenders("cached/styles.css", "/static/cached/styles.deploy12345.css")
+        self.assertStaticRenders("path/", "/static/path/")
+        self.assertStaticRenders("path/?query", "/static/path/?query")
+
+    def test_template_tag_simple_content(self):
+        relpath = self.hashed_file_path("cached/styles.css")
+        self.assertEqual(relpath, "cached/styles.deploy12345.css")
+        with storage.staticfiles_storage.open(relpath) as relfile:
+            content = relfile.read()
+            self.assertNotIn(b"cached/other.css", content)
+            self.assertIn(b"other.deploy12345.css", content)
+
+
+class CustomStaticFilesStorage(storage.StaticFilesStorage):
+    """
+    Used in TestStaticFilePermissions
+    """
+    def __init__(self, *args, **kwargs):
+        kwargs['file_permissions_mode'] = 0o640
+        kwargs['directory_permissions_mode'] = 0o740
+        super().__init__(*args, **kwargs)
+
+
+@unittest.skipIf(sys.platform == 'win32', "Windows only partially supports chmod.")
+class TestStaticFilePermissions(CollectionTestCase):
+
+    command_params = {
+        'interactive': False,
+        'verbosity': 0,
+        'ignore_patterns': ['*.ignoreme'],
+    }
+
+    def setUp(self):
+        self.umask = 0o027
+        self.old_umask = os.umask(self.umask)
+        super().setUp()
+
+    def tearDown(self):
+        os.umask(self.old_umask)
+        super().tearDown()
+
+    # Don't run collectstatic command in this test class.
+    def run_collectstatic(self, **kwargs):
+        pass
+
+    @override_settings(
+        FILE_UPLOAD_PERMISSIONS=0o655,
+        FILE_UPLOAD_DIRECTORY_PERMISSIONS=0o765,
+    )
+    def test_collect_static_files_permissions(self):
+        call_command('collectstatic', **self.command_params)
+        static_root = Path(settings.STATIC_ROOT)
+        test_file = static_root / 'test.txt'
+        file_mode = test_file.stat().st_mode & 0o777
+        self.assertEqual(file_mode, 0o655)
+        tests = [
+            static_root / 'subdir',
+            static_root / 'nested',
+            static_root / 'nested' / 'css',
+        ]
+        for directory in tests:
+            with self.subTest(directory=directory):
+                dir_mode = directory.stat().st_mode & 0o777
+                self.assertEqual(dir_mode, 0o765)
+
+    @override_settings(
+        FILE_UPLOAD_PERMISSIONS=None,
+        FILE_UPLOAD_DIRECTORY_PERMISSIONS=None,
+    )
+    def test_collect_static_files_default_permissions(self):
+        call_command('collectstatic', **self.command_params)
+        static_root = Path(settings.STATIC_ROOT)
+        test_file = static_root / 'test.txt'
+        file_mode = test_file.stat().st_mode & 0o777
+        self.assertEqual(file_mode, 0o666 & ~self.umask)
+        tests = [
+            static_root / 'subdir',
+            static_root / 'nested',
+            static_root / 'nested' / 'css',
+        ]
+        for directory in tests:
+            with self.subTest(directory=directory):
+                dir_mode = directory.stat().st_mode & 0o777
+                self.assertEqual(dir_mode, 0o777 & ~self.umask)
+
+    @override_settings(
+        FILE_UPLOAD_PERMISSIONS=0o655,
+        FILE_UPLOAD_DIRECTORY_PERMISSIONS=0o765,
+        STATICFILES_STORAGE='staticfiles_tests.test_hashed_storage.CustomStaticFilesStorage',
+    )
+    def test_collect_static_files_subclass_of_static_storage(self):
+        call_command('collectstatic', **self.command_params)
+        static_root = Path(settings.STATIC_ROOT)
+        test_file = static_root / 'test.txt'
+        file_mode = test_file.stat().st_mode & 0o777
+        self.assertEqual(file_mode, 0o640)
+        tests = [
+            static_root / 'subdir',
+            static_root / 'nested',
+            static_root / 'nested' / 'css',
+        ]
+        for directory in tests:
+            with self.subTest(directory=directory):
+                dir_mode = directory.stat().st_mode & 0o777
+                self.assertEqual(dir_mode, 0o740)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/staticfiles/storage\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 staticfiles_tests.test_hashed_storage
cat coverage.cover
git checkout 179ee13eb37348cd87169a198aec18fedccc8668
git apply /root/pre_state.patch
