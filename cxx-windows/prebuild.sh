if [ -d "./cxx-windows/" ];then
    rm -r ./cxx-windows
fi

mkdir ./cxx-windows

sed 's/\#include \"quickjs\/quickjs.h\"/\#include \"quickjs.h\"/g' ../cxx-windows/ffi.h > ./cxx-windows/ffi.h
cp ../cxx-windows/ffi.cpp ./cxx-windows/ffi.cpp

cp -r ../cxx-windows/quickjs/* ./cxx-windows

rm ./cxx-windows/quickjs.c


quickjs_version=$(cat ../cxx-windows/quickjs/VERSION)

sed '1i\
\#define CONFIG_VERSION \"'$quickjs_version'\"\
\#define DUMP_LEAKS  1\
' ../cxx-windows/quickjs/quickjs.c > ./cxx-windows/quickjs.c