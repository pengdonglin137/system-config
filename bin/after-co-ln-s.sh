#!/bin/bash
set -e
touch ~/.authinfo ~/.netrc
chmod og-rwx ~/.authinfo ~/.netrc
umask 0022

my_uname=$(uname)
my_uname=${uname%-*}

export PATH=/opt/local/libexec/gnubin:~/system-config/bin/Linux:~/system-config/bin:$PATH:/bin:/usr/bin
PATH=~/system-config/bin/$my_uname:$PATH

if test ! -d ~/system-config/.git && test -d ~/system-config/; then
    if yes-or-no-p "system-config not a git repo, git init?"; then
        (
            cd ~/system-config/
            ln -sf ~/system-config/.gitconfig.bhj ~/.gitconfig
            git init .
            git add .
            git commit -m 'init version of system-config'
        )
    fi
fi

if test "$USER" != bhj -a "$1" != -i; then
    exec < /dev/null
fi

export can_sudo=true
if test -e /etc/sudoers.d/$USER -a "$USER" = bhj; then
    # can do sudo, but only if it's bhj
    function sudo() {
        echo SUDO: "$@"
        command sudo -E env PATH="$PATH"  "$@"
    }
    export -f sudo
elif ! yes-or-no-p "Do you have sudo power?"; then
    function sudo() {
        true
    }
    export -f sudo
    can_sudo=false
fi

function can-sudo-and-yes-or-no-p() {
    test "$can_sudo" = true && yes-or-no-p "$@"
}

function can-sudo-and-ask-if-not-bhj() {
    test "$can_sudo" = true && ask-if-not-bhj "$@"
}

if test -d /etc/sudoers.d/ -a ! -e /etc/sudoers.d/$USER && can-sudo-and-ask-if-not-bhj "Make your sudo command not ask for password?"; then
    sudo bash -c "perl -npe 's/bhj/$USER/g' $HOME/system-config/etc/sudoers.d/bhj > /etc/sudoers.d/$USER; chmod 440 /etc/sudoers.d/$USER"
fi

if test $can_sudo = true -a $USER = bhj; then
    mkdir -p ~/.ssh/
    touch ~/.ssh/config
fi

if ! which sudo >/dev/null 2>&1 ; then # for cygwin, where sudo is not available
    function sudo() {
        "$@"
    }
    export -f sudo
    can_sudo=false
fi

if ! which git >/dev/null 2>&1 ; then
    sudo apt-get install -y git || /cygdrive/c/setup-x86_64.exe -q -n -d -A -P git
fi

mkdir -p ~/Downloads/forever ~/external/local ~/.cache/system-config/logs ~/.config/system-config

if test -d ~/src/github/external-etc/; then
    rm -rf ~/external/etc || true
    relative-link ~/src/github/external-etc ~/external/etc
else
    for x in 15m hourly daily weekly; do
        mkdir -p ~/external/etc/cron.d/$x;
    done
    mkdir -p ~/external/etc/at
fi

if test $can_sudo = true && test $(uname)  = Linux -a ! -e ~/.config/system-config/offline-is-unstable; then
    (sudo apt-get install -y -t unstable offlineimap >/dev/null 2>&1 && touch ~/.config/system-config/offline-is-unstable) || true
fi

touch ~/.cache/system-config/.where.bak
rm -f ~/tmp >/dev/null 2>&1 || true
mkdir -p ~/tmp
cd ~/system-config/

uname=$(uname|perl -npe 's/_.*//')
mkdir -p ~/external/bin/$uname/ext
mkdir -p ~/.cache/system-config/notification-manager

echo ~/external/etc/at >> ~/.cache/system-config/.where

function die() {
    echo "$@"
    exit -1
}

if test $uname = CYGWIN; then
    if test $(uname) = CYGWIN_NT-5.1; then
        export PATH=~/system-config/bin/windows:$PATH
        function do_ln_1() {
            junction "$1" "$2"
        }
    else
        function do_ln_1() {
            if test -d "$2" -o -d "$1"; then
                dflag=/d
            else
                dflag=
            fi
            echo cmd.exe /c mklink $dflag "$1" "$2"
            cmd.exe /c mklink $dflag "$1" "$2" >/dev/null 2>&1
        }
    fi

    function ln() {
        soft=false
        force=false
        TEMP=$(getopt -o sf --long soft,force -n ln -- "$@")
        eval set -- "$TEMP"
        while true; do
            case "$1" in
                -s|--soft)
                    soft=true
                    shift
                    ;;
                -f|--force)
                    force=true
                    shift
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    die "internal error: $(. bt; echo; bt | indent-stdin)"
                    ;;
            esac
        done

        if test $soft = false; then
            die "Can not do hard link";
        fi

        if test $# = 1; then
            set -- $# .
        fi

        args=("$@")

        last=${args[${#args[@]} - 1]}
        n_args=${#args[@]}

        if test $n_args -gt 2 -a ! -d "$last"; then
            die "$last not directory"
        fi

        if test ! -d "$last" -a -e "$last"; then
            if test $force = false; then
                die "$last already exist"
            else
                rm "$last"
            fi
        fi



        for n in $(seq 0 $((${#args[@]} - 2))); do
            dest=$last
            if test -d $last; then
                dest=$last/$(basename ${args[$n]})
            fi

            if test $force = true; then
                rm -f $dest
            elif test -e $dest; then
                die "$dest already exist"
            fi
            do_ln_1 "$(cygpath -wa "$dest")" "$(cygpath -wa "${args[$n]}")"
        done
    }
fi


function symlink-map-files() {
    if test $# != 2; then
        die "Error: symlink-map-files FROM TO"
    fi

    cd "$1"
    for x in $(git ls-tree --name-only HEAD -r); do
        if test $(basename $x) = .dir-locals.el; then
            continue
        fi

        if test -e "$2"/$x -a "$(readlink -f "$2"/$x)" != "$(readlink -f "$1"/$x)"; then
            echo "Warning: "$2"/$x already exist and it's not softlink to "$1"/$x"
            mv "$2"/$x "$2"/$x.bak
            ln -s "$1"/$x "$2"/$x
        elif test ! -e "$2"/$x; then
            mkdir -p "$(dirname "$2"/$x)"
            ln -sf "$1"/$x "$2"/$x
        fi
    done
}

function symlink-map() {
    if test $# != 2; then
        die "Error: symlink-map FROM TO"
    fi

    cd "$1"

    for x in `git ls-tree --name-only HEAD`
    do
        if test $(basename $x) = .dir-locals.el; then
            continue
        fi

        if test -e "$2"/$x -a "$(readlink -f "$2"/$x)" != "$(readlink -f "$1"/$x)";
        then
            echo "Warning: "$2"/$x already exist and it's not softlink to "$1"/$x"
            mv "$2"/$x "$2"/$x.bak
            ln -s "$1"/$x "$2"/
        elif ! test -e "$2"/$x;
        then
            ln -sf "$1"/$x "$2"/
        fi
    done

}

if grep -q "# hooked up for system-config" ~/.bashrc || test "$(readlink -f ~/.bashrc)" = "$(readlink -f ~/system-config/.bashrc)"; then
    true
else
    cat <<EOF >> ~/.profile
if test -e ~/system-config/.profile; then
   . ~/system-config/.profile
   # hooked up for system-config
fi
EOF

    cat <<EOF >> ~/.emacs
(when (file-exists-p "~/system-config/.emacs")
  (load "~/system-config/.emacs"))
EOF

    cat <<EOF >> ~/.bashrc
if test -e ~/system-config/.bashrc; then
    . ~/system-config/.bashrc
    # hooked up for system-config
fi
EOF
fi

for x in $(find ~/system-config/.sc-symlinks/ -type l); do
    if test ! -e "$x"; then
        continue
    fi
    base=$(basename "$x");
    if test "$(readlink -f ~/"$base")" = "$(readlink -f "$x")"; then
        # echo already linked system-config\'s version of  ~/"$base"
        continue
    fi
    if test ! -e ~/"$base" || ask-if-not-bhj "Use system-config's version of ~/$base?"; then
        if test -e ~/"$base"; then
            mv ~/"$base" ~/"$base".$(now)
        fi
        ln -s "$x" ~/"$base"
    fi
done

if test "$USER" = bhj; then
    symlink-map-files ~/system-config/etc/subdir-symlinks ~
    mkdir -p ~/.local/share/applications
    symlink-map ~/system-config/etc/local-app/ ~/.local/share/applications
else
    mkdir -p ~/.config/autostart
    cp ~/system-config/etc/subdir-symlinks/.config/autostart/xbindkeys.desktop  ~/.config/autostart
fi

if test -e ~/system-config/.gitconfig.$USER &&
        test "$(readlink -f ~/system-config/.gitconfig.$USER)" != "$(readlink -f ~/.gitconfig)"; then
    ln -sf ~/system-config/.gitconfig.$USER ~/.gitconfig
elif test ! -e ~/system-config/.gitconfig.$USER &&
        test ! -e ~/.gitconfig; then
    cp ~/system-config/.gitconfig.bhj ~/.gitconfig || true
    name=$(finger $USER 2>/dev/null | grep Name: | perl -npe 's/.*Name: //')
    if test "$name"; then
        git config --global user.name "$name"
    else
        git config --global user.name "$USER"
    fi
    if read -p "What is your email address (nobody@example.com)? " email; then
        true
    else
        true
    fi
    git config --global user.email "${email:-nobody@example.com}"
    ln -sf ~/.gitconfig ~/.gitconfig.$USER

    if test "$(compare-version "$(git version | awk '{print $3}')" 2)" = '<'; then
        git config --unset --global push.default
    fi
fi

ln -sf .offlineimaprc-$(uname|perl -npe 's/_.*//') ~/.offlineimaprc

if ask-if-not-bhj "Do you want to use bhj's git-exclude file?"; then
    git config --global core.excludesfile '~/system-config/.git-exclude'
fi

if ask-if-not-bhj "Do you want to switch the ctrl/alt, esc/caps_lock keys?"; then
    mach=$(get-about-me mach)
    if test -d ~/system-config/etc/hardware-mach/$mach; then
        relative-link -f ~/system-config/etc/hardware-mach/$mach/.Xmodmap ~/.Xmodmap
    fi
fi

if ! diff >/dev/null 2>&1 -q ~/system-config/etc/rc.local /etc/rc.local; then
    if grep -q '# from system-config' /etc/rc.local >/dev/null 2>&1; then
        bhj-notify 'rc.local' 'You need to update /etc/rc.local':"$(diff /etc/rc.local ~/system-config/etc/rc.local)"
    fi
    if can-sudo-and-yes-or-no-p "Replace /etc/rc.local with system-config's version? (please check it first!)"; then
        sudo cp ~/system-config/etc/rc.local /etc >/dev/null 2>&1 || true # no sudo on win32
    fi
fi
mkdir -p ~/system-config/bin/$(uname|perl -npe 's/_.*//')/ext/`uname -m`/
if test -L ~/.git; then rm -f ~/.git; fi
if test $(uname) = Linux; then
    if test $can_sudo = true && grep managed=true /etc/NetworkManager/NetworkManager.conf; then
        sudo perl -npe 's/managed=true/managed=false/' -i /etc/NetworkManager/NetworkManager.conf;
    fi
fi


if test -e ~/src/github/ahd/ -a ! -e ~/src/ahd; then
    ln -s ~/src/github/ahd/ ~/src/ahd
fi

if test -e ~/src/github/private-config/.bbdb; then
    ln -s ~/src/github/private-config/.bbdb ~/ -f
fi

if test ! -d ~/.config/system-config/about_me; then
    mkdir -p ~/.config/system-config/about_me;
fi

if uname | grep cygwin -i; then # the following are for linux only
    exit 0
fi

set-use-my-own-firefox

if test ! -d ~/.config/system-config/about_me && yes-or-no-p "You want to configure your about_me?"; then
    after-co-settings.sh
fi

if test -x ~/src/github/private-config/bin/bhj-after-co.sh; then
    ~/src/github/private-config/bin/bhj-after-co.sh
fi


if ! diff -q ~/system-config/etc/systemd/system/rc-local.service /etc/systemd/system/rc-local.service >/dev/null 2>&1; then
    if which systemctl >/dev/null 2>&1 && test ! -e /etc/systemd/system/rc-local.service && test -d /etc/systemd/system/; then
        sudo cp ~/system-config/etc/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
        sudo chmod a+X /etc/systemd/system/rc-local.service
        sudo systemctl --system daemon-reload
        sudo systemctl enable rc-local.service
        sudo systemctl start rc-local.service
    else
        sudo cp ~/system-config/etc/systemd/system/rc-local.service /etc/systemd/system/rc-local.service || true
    fi
fi

if test ! -d /etc/acpi/local/; then
    sudo mkdir -p /etc/acpi/local/
fi

mkdir -p ~/.cache # just in case the following command will create
# .cache with root permission.

(
    set +e
    if test -d ~/system-config/src/github/; then
        exit
    fi
    (
        cd ~/src/github/mobileorg-android/ &&
            git remote add up https://github.com/matburt/mobileorg-android
    )

    (
        cd ~/src/github/emacs.d &&
            git remote add up https://github.com/purcell/emacs.d
    )

    (
        cd ~/src/github/autoproxy &&
            git remote add up https://github.com/agunchan/autoproxy
    )

    (
        cd ~/src/github/shadowsocks-android &&
            git remote add up https://github.com/shadowsocks/shadowsocks-android
    )

    (
        cd ~/src/github/adb-sync/ &&
            git remote add up https://github.com/google/adb-sync
    )
) >/dev/null 2>&1 || true

~/system-config/bin/Linux/emacs-install-packages || true

if test -d ~/system-config/src/github/; then
    mkdir -p ~/src/github/
    for x in ~/system-config/src/github/*/; do
        if test -d "$x" -a ! -d ~/src/github/"$(basename "$x")"; then
            relative-link $x ~/src/github
        fi
    done
fi

if test -d ~/src/github/elpa; then
    force-symlink ~/src/github/elpa ~/.emacs.d/elpa
fi || true

if test $can_sudo = true; then
    check-perl-module String::ShellQuote
    check-perl-module Marpa::R2
fi
(
    cd ~/system-config/
    for x in .*.bhj; do
        relative-link $x ../${x%.bhj} || true
    done
) >/dev/null 2>&1 &

if test "$FORCE_ANDROID_BUILD_INSTALL" = true; then
    install-pkgs --check-first android-build || true

    if ! install-pkgs --check-only android-build; then
        hint "有一些安卓编译需要的系统程序安装失败，请仔细阅读上面的终端输出，检查其失败原因（也可以运行 install-pkgs --check-first android-build 重新安装）。

注意某些重要的程序没有安装的话，可能导致安卓无法正常编译。一般来讲，CM 整理的安卓编译所需安装包每一个都能正确安装，所以你不应该看到这句提示信息，除非你在试验新的系统版本（比如最新的 Ubuntu 等等）；或者你的系统有了严重的安装包依赖混乱问题，导致有些包怎么也装不上"
        if yes-or-no-p -y "有安装包安装失败，是否退出（选否的话会尝试继续配置安卓开发环境，所以如果你是在试验新的 Ubuntu 系统，请输入“No”并回车）？"; then
            hint "即将退出，本次配置 system-config 环境失败，请检查、解决安装包问题后重试。"
            exit 1
        fi
    fi
fi

echo Simple config OK.
