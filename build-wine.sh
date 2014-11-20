#!/bin/bash

function copy-dlls()
{
    rsync windows/binaries/* ./release -v -L
    rsync t1wrench.lua ./release -v

    for x in icudt52.dll icuin52.dll icuuc52.dll QT5CORE.DLL QT5GUI.DLL QT5WIDGETS.DLL; do
        rsync $(find $1/bin/ -maxdepth 1 -iname $x) ./release -av
        chmod 555 $(find ./release/ -iname $x)
    done

    for x in libEGL.dll libGLESv2.dll libstdc++-6.dll libwinpthread-1.dll libgcc_s_dw2-1.dll; do
        rsync $(find $1/bin/ -maxdepth 1 -iname $x | grep . || echo $1/bin/$x) ./release -av || continue
        chmod 555 $(find ./release/ -iname $x)
    done

    mkdir -p ./release/platforms
    rsync $1/plugins/platforms/qwindows.dll ./release/platforms -av
    chmod 555 ./release/platforms/*
}

function make-release-tgz()
{
    rsync readme.* ./release/
    rsync -av *.png ./release/
    command rsync -av -d release/ t1wrench-release --exclude="*.obj" \
            --exclude="*.o" \
            --exclude="*.cpp"


    set -x
    (
        zip -r ${1:-T1Wrench-windows.zip} T1Wrench-windows
        smb-push ${1:-T1Wrench-windows.zip} ~/smb/share.smartisan.cn/share/baohaojun/T1Wrench
        rsync T1Wrench-windows.zip rem:/var/www/html/baohaojun/ -v
    )&
    command rsync T1Wrench-windows/ $release_dir -av -L --delete --exclude=.git
}


set -e
set -o pipefail

function wine() {
    cat > build.bat<<EOF
set path=c:/Qt-mingw/Qt5.3.1/5.3/mingw482_32/bin;c:/Qt-mingw/Qt5.3.1/Tools/mingw482_32/bin;%path
$@
EOF
    command wine cmd.exe /c build.bat
}

build_dir=~/tmp/build-t1-windows
release_dir=~/src/github/T1Wrench-windows
rsync * $build_dir -av
cd $build_dir


(
    cd lua
    PATH=~/bin/mingw:$PATH make mingw
)

if test ! -e Makefile; then
    wine qmake.exe
fi
wine mingw32-make.exe -j8 | perl -npe 's/\\/\//g'
copy-dlls /cygdrive/c/Qt-mingw/./Qt5.3.1/5.3/mingw482_32
set -x
rm -f T1Wrench-windows
ln -sf t1wrench-release T1Wrench-windows
make-release-tgz
(
    cd $release_dir
    rm build.bat -f
    command wine ./T1Wrench.exe
)
