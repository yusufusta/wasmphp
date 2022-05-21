#!/usr/bin/env bash
echo "wasmphp"
set -e

PHP_BRANCH=PHP-8.1.6

apt-get update && apt-get install git

if [[ ! -d php-src ]]; then
    echo "[INFO] Downloading $PHP_BRANCH"
    git clone https://github.com/php/php-src.git --branch $PHP_BRANCH --single-branch --no-tags --depth 1
fi

apt-get install -y autoconf libc-dev bison re2c make
cd php-src

echo "[INFO] Downloading Emscripten extension"
git clone https://github.com/yusufusta/emscriptenphp ext/emscripten
echo "[INFO] Configuring PHP"
./buildconf --force

emconfigure ./configure \
  --disable-all \
  --disable-cgi \
  --disable-cli \
  --disable-rpath \
  --disable-phpdbg \
  --with-valgrind=no \
  --without-pear \
  --without-pcre-jit \
  --with-layout=GNU \
  --enable-embed=static \
  --enable-bcmath \
  --enable-json \
  --enable-ctype \
  --enable-mbstring \
  --disable-mbregex \
  --enable-tokenizer \
  --enable-emscripten \
  --disable-fiber-asm 

echo "[INFO] Building PHP"

emmake make -j8
mkdir -p out
emcc -c -O3 -I . -I Zend -I main -I TSRM/ ../php_eval.c -o php_eval.o
emcc -O3 \
  --llvm-lto 2 \
  -s ENVIRONMENT=web \
  -s EXPORTED_FUNCTIONS='["_php_eval", "_php_embed_init", "_zend_eval_string", "_php_embed_shutdown"]' \
  -s EXTRA_EXPORTED_RUNTIME_METHODS='["ccall"]' \
  -s MODULARIZE=1 \
  -s EXPORT_NAME="PHP" \
  -s TOTAL_MEMORY=134217728 \
  -s ASSERTIONS=0 \
  -s INVOKE_RUN=0 \
  -s ERROR_ON_UNDEFINED_SYMBOLS=0 \
  --preload-file Zend/bench.php \
  libs/libphp.a php_eval.o -o out/php.js

cp out/php.wasm out/php.js out/php.data ..

echo "OK"