#!/bin/sh

entered_text=""
text="the quick brown fox jumps over the lazy dog"

tty_init () {
    tput clear
    export SAVED_TTY_SETTINGS=$(stty -g)
    stty raw -echo
    trap typr_cleanup 1 2 3 6

    printf "[3 q[0;0H"

}

tty_cleanup () {
    tput clear
    stty $SAVED_TTY_SETTINGS
}

tty_readc () {
    stty -echo -icanon min 1 time 0
    s="$(dd bs=1 count=1 of=/dev/stdout 2>/dev/null)"
    stty -icanon min 0 time 0
    [ "$s" = "" ]  && {
        s="$s$(dd bs=1 count=2 of=/dev/stdout 2>/dev/null)"
    }
    printf "$s"
}

typr_draw_text () {
    tput civis
    tput clear
    printf "[0;0H"

    t="$text"
    e="$entered_text"
    while [ "$t" ] ; do
        ct=${t%${t#?}}
        ce=${e%${e#?}}
        t="${t#?}"
        e="${e#?}"

        [ "$ct" = "$ce" ] \
            && printf "[0;32m" \
            || {
            [ "$e" ] \
                    && printf "[0;31m" \
                    || printf "[0;37m"
            }

        printf "$ct"
    done
    printf "[1;$((${#entered_text} + 1))H"
    tput cnorm
}


typr_main () {
    while true; do
        typr_draw_text
        c="$(tty_readc)"
        case "$c" in
            '') break;;
            '')
                entered_text="${entered_text%?}"
                ;;
            *)
                echo "$c" >> LOG
                entered_text="$entered_text$c"
                ;;

        esac
    done
}

typr_init () {
    tty_init
    typr_main
    tty_cleanup
}

typr_init
