#!/bin/sh

words="the be of and a to in he have it that for they I with as not on she at by this we you do but from or which one would all will there say who make when can more if no man out other so what time up go about than into could state only new year some take come these know see use get like then first any work now may such give over think most even find day also after way many must look before great back through long where much should well people down own just because good each those feel seem how high too place little world very still nation hand old life tell write become here show house both between need mean call develop under last right move thing general school never same another begin while number part turn real leave might want point form off child few small since against ask late home interest large person end open public follow during present without again hold govern around possible head consider word program problem however lead system set order eye plan run keep face fact group play stand increase early course change help line"
entered_text=""
text=""

tty_init () {
    tput clear
    export SAVED_TTY_SETTINGS=$(stty -g)
    stty raw -echo
    trap typr_cleanup 1 2 3 6

    printf "[6 q[0;0H"
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

    cols="$(tput cols)"
    lines="$(tput lines)"

    startcol=$((cols / 3))
    line=$((lines / 3))
    cpos="0;0"

    color="[0;37m"

    tput civis

    cpos="${line};${startcol}"
    printf "[${cpos}H${color}"

    i=0
    t="$text"
    e="$entered_text"
    while [ "$t" ] ; do
        ct=${t%${t#?}}
        ce=${e%${e#?}}
        t="${t#?}"
        e="${e#?}"


        [ "$ct" != "$ce" ] \
            && newcolor="[0;31m" \
            || newcolor="[0;32m"

        [ ! "$ce" ] && newcolor="[0;37m" \

        [ "$color" != "$newcolor" ] && {
            color="$newcolor"
            printf "$newcolor"
            [ "$color" = "[0;37m" ] && cpos="${line};$((i+$startcol))"
        }


        [ "$i" -gt "$startcol" ] && {
            line=$((line+1))
            printf "[${line};${startcol}H"
            i=0
        }

        printf "$ct"
        i=$((i+1))
    done
    printf "[${cpos}H"
    tput cnorm
}

typr_generate_text () {
    words="$(printf "%s " $words | shuf)"
    wordcount=100

    set -- $words
    text=""

    i=0
    while [ "$i" -lt "$wordcount" ]; do
        text="$1 $text"
        shift
        i=$((i+1))
    done
    text="${text% }"
}


typr_main () {
    while true; do
        typr_draw_text
        c="$(tty_readc)"
        case "$c" in
            ''|'') break;;
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
    typr_generate_text
    typr_main
    tty_cleanup
}

typr_init
