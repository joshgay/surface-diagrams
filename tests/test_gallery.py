import importlib.util
from pathlib import Path
import tempfile
import unittest
from xml.etree import ElementTree as ET


class GalleryTest(unittest.TestCase):
    def test_all_examples_generate_and_parse(self):
        file=Path(__file__).resolve().parents[1]/'examples'/'gallery.py'
        spec=importlib.util.spec_from_file_location('gallery',file)
        gallery=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gallery)
        with tempfile.TemporaryDirectory() as temp:
            index=gallery.make_gallery(temp)
            self.assertTrue(index.exists())
            files=list(Path(temp).glob('*.svg'))
            registry=gallery.gallery_examples()
            self.assertEqual(len(files),sum(len(v) for v in registry.values())+len(registry))
            for file in files:
                with self.subTest(file=file.name):
                    self.assertEqual(ET.parse(file).getroot().tag,'{http://www.w3.org/2000/svg}svg')


if __name__=='__main__': unittest.main()
