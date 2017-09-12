# Targets:
#    all        Build all styles in all formats (default)
#    all_ttf    Build all styles as TrueType
#    STYLE      Build STYLE in all formats (e.g. MediumItalic)
#    STYLE_ttf  Build STYLE as TrueType (e.g. MediumItalic_ttf)
#    zip        Build all styles as TrueType and package into a zip archive
#
all: all_web all_otf

VERSION := $(shell misc/version.py)

# generated.make is automatically generated by init.sh and defines depenencies for
# all styles and alias targets
include build/etc/generated.make

res_files := src/fontbuild.cfg src/diacritics.txt src/glyphlist.txt \
             src/features.fea src/glyphorder.txt

# UFO -> TTF & OTF (note that UFO deps are defined by generated.make)
build/tmp/InterfaceTTF/Interface-%.ttf: $(res_files)
	misc/ufocompile --otf $*

build/tmp/InterfaceOTF/Interface-%.otf: build/tmp/InterfaceTTF/Interface-%.ttf $(res_files)
	@true

# build/tmp/ttf -> build (generated.make handles build/tmp/InterfaceTTF/Interface-%.ttf)
build/dist-unhinted/Interface-%.ttf: build/tmp/InterfaceTTF/Interface-%.ttf
	@mkdir -p build/dist-unhinted
	cp -a "$<" "$@"

# OTF
build/dist-unhinted/Interface-%.otf: build/tmp/InterfaceOTF/Interface-%.otf
	@mkdir -p build/dist-unhinted
	cp -a "$<" "$@"

build/dist:
	@mkdir -p build/dist

# autohint
build/dist/Interface-%.ttf: build/dist-unhinted/Interface-%.ttf build/dist
	ttfautohint \
	  --hinting-limit=256 \
	  --hinting-range-min=8 \
	  --hinting-range-max=64 \
	  --fallback-stem-width=256 \
	  --strong-stem-width=D \
	  --no-info \
	  --verbose \
	  "$<" "$@"

# TTF -> WOFF2
build/%.woff2: build/%.ttf
	woff2_compress "$<"

# TTF -> WOFF
build/%.woff: build/%.ttf
	ttf2woff -O -t woff "$<" "$@"

# TTF -> EOT (disabled)
# build/%.eot: build/%.ttf
# 	ttf2eot "$<" > "$@"

ZIP_FILE_DIST := build/release/Interface-${VERSION}.zip
ZIP_FILE_DEV  := build/release/Interface-${VERSION}-$(shell git rev-parse --short=10 HEAD).zip

# zip intermediate
build/.zip.zip: all
	@rm -rf build/.zip
	@rm -f build/.zip.zip
	@mkdir -p \
		"build/.zip/Interface (web)" \
		"build/.zip/Interface (hinted TTF)" \
		"build/.zip/Interface (TTF)" \
		"build/.zip/Interface (OTF)"
	@cp -a build/dist/*.woff build/dist/*.woff2  "build/.zip/Interface (web)/"
	@cp -a build/dist/*.ttf                      "build/.zip/Interface (hinted TTF)/"
	@cp -a build/dist-unhinted/*.ttf             "build/.zip/Interface (TTF)/"
	@cp -a build/dist-unhinted/*.otf             "build/.zip/Interface (OTF)/"
	@cp -a misc/doc/install-*.txt                "build/.zip/"
	@cp -a LICENSE.txt                           "build/.zip/"
	cd build/.zip && zip -v -X -r "../../build/.zip.zip" * >/dev/null && cd ../..
	@rm -rf build/.zip

# zip
build/release/Interface-%.zip: build/.zip.zip
	@mkdir -p "$(shell dirname "$@")"
	@mv -f "$<" "$@"
	@echo write "$@"

zip: ${ZIP_FILE_DEV}
zip_dist: ${ZIP_FILE_DIST}

pre_dist:
	@echo "Creating distribution for version ${VERSION}"
	@if [ -f "${ZIP_FILE_DIST}" ]; \
		then echo "${ZIP_FILE_DIST} already exists. Bump version or remove the zip file to continue." >&2; \
		exit 1; \
  fi
dist: pre_dist zip_dist glyphinfo copy_docs_fonts
	misc/versionize-css.py
	@echo "——————————————————————————————————————————————————————————————————"
	@echo ""
	@echo "Next steps:"
	@echo ""
	@echo "1) Commit & push changes"
	@echo ""
	@echo "2) Create new release with ${ZIP_FILE_DIST} at"
	@echo "   https://github.com/rsms/interface/releases/new?tag=v${VERSION}"
	@echo ""
	@echo "3) Bump version in src/fontbuild.cfg and commit"
	@echo ""
	@echo "——————————————————————————————————————————————————————————————————"

copy_docs_fonts:
	rm -rf docs/font-files
	mkdir docs/font-files
	cp -a build/dist/*.woff build/dist/*.woff2 build/dist-unhinted/*.otf docs/font-files/

install_ttf: all_ttf
	@echo "Installing TTF files locally at ~/Library/Fonts/Interface"
	rm -rf ~/Library/Fonts/Interface
	mkdir -p ~/Library/Fonts/Interface
	cp -va build/dist/*.ttf ~/Library/Fonts/Interface

install_otf: all_otf
	@echo "Installing OTF files locally at ~/Library/Fonts/Interface"
	rm -rf ~/Library/Fonts/Interface
	mkdir -p ~/Library/Fonts/Interface
	cp -va build/dist-unhinted/*.otf ~/Library/Fonts/Interface

install: all install_otf


glyphinfo: docs/lab/glyphinfo.json docs/glyphs/metrics.json

src/glyphorder.txt: src/Interface-Regular.ufo/lib.plist src/Interface-Black.ufo/lib.plist src/diacritics.txt misc/gen-glyphorder.py
	misc/gen-glyphorder.py src/Interface-*.ufo > src/glyphorder.txt

docs/lab/glyphinfo.json: _local/UnicodeData.txt src/glyphorder.txt misc/gen-glyphinfo.py
	misc/gen-glyphinfo.py -ucd _local/UnicodeData.txt \
	  src/Interface-*.ufo > docs/lab/glyphinfo.json

docs/glyphs/metrics.json: src/glyphorder.txt misc/gen-metrics-and-svgs.py $(Regular_ufo_d)
	misc/gen-metrics-and-svgs.py -f src/Interface-Regular.ufo


# Download latest Unicode data
_local/UnicodeData.txt:
	@mkdir -p _local
	curl -s '-#' -o "$@" \
	  http://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt

clean:
	rm -vrf build/tmp/* build/dist/Interface-*.*

.PHONY: all web clean install install_otf install_ttf deploy zip zip_dist pre_dist dist glyphinfo copy_docs_fonts
