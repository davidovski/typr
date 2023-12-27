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
    color="[0;37m"
    line=${areay}
    startcol=${areax}

    cpos="${line};${startcol}"
    draw="[${cpos}H${color}"

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
            draw="${draw}$newcolor"
            [ "$color" = "[0;37m" ] && cpos="${line};$((i+$startcol))"
        }


        [ "$i" -gt "$startcol" ] && {
            line=$((line+1))
            draw="${draw}[${line};${startcol}H"
            i=0
        }

        [ "$ct" = " " ] && [ "$color" = "[0;31m" ] \
         && draw="${draw}_" \
         || draw="$draw$ct"

        i=$((i+1))
    done
    printf "%s[${cpos}H" "$draw"
    tput cnorm
}

typr_get_time () {
    now="$(date +%s%N)"
    time_ns=$((now-start))

    time_ms=$(((time_ns/1000000)%1000))
    time_seconds=$(((time_ns/1000000000)%60))
    time_minutes=$((time_ns/60000000000))
    
    printf "%02d:%02d.%03d" "$time_minutes" "$time_seconds" "$time_ms"
}

typr_draw_time () {
    printf "[s[$((areay-1));${areax}H[0m%s[u" "$(typr_get_time)"
}

typr_show_results () {
    now="$(date +%s%N)"
    time_ns=$((now-start))

    time_ms=$(((time_ns/1000000)%1000))
    time_seconds=$(((time_ns/1000000000)%60))
    time_minutes=$((time_ns/60000000000))

    words=$(set -- $text; printf "%s\n" "$#")
    wpm="$((time_ns*words/60000000000))"
    
    printf "[$((areay-1));${areax}H[0mtime: %02d:%02d.%03d\twpm: %s" "$time_minutes" "$time_seconds" "$time_ms" "$wpm"
    
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


typr_draw_loop () {
    while true; do
        typr_draw_time
    done
}


typr_main () {
    start="$(date +%s%N)"

    typr_draw_loop &
    draw_pid="$!"

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

        [ "${#entered_text}" = "${#text}" ] && break
    done
    kill "$draw_pid"

    while true; do
        case "$(tty_readc)" in
            ''|'') break;;
        esac
    done
}

typr_init () {
    cols="$(tput cols)"
    lines="$(tput lines)"

    areax=$((cols / 3))
    areay=$((lines / 3))
    tty_init
    typr_generate_text
    typr_main
    tty_cleanup
}

typr_init
