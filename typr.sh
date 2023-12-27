#!/bin/sh

words="the be of and a to in he have it that for they i with as not on she at by this we you do but from or which one would all will there say who make when can more if no man out other so what time up go about than into could state only new year some take come these know see use get like then first any work now may such give over think most even find day also after way many must look before great back through long where much should well people down own just because good each those feel seem how high too place little world very still nation hand old life tell write become here show house both between need mean call develop under last right move thing general school never same another begin while number part turn real leave might want point form off child few small since against ask late home interest large person end open public follow during present without again hold govern around possible head consider word program problem however lead system set order eye plan run keep face fact group play stand increase early course change help line"

entered_text=""
text=""

tty_init () {
    printf "[2J"
    export SAVED_TTY_SETTINGS=$(stty -g)
    stty raw -echo
    trap typr_cleanup 1 2 3 6

    printf "[6 q[0;0H"
}

tty_cleanup () {
    stty $SAVED_TTY_SETTINGS
    printf "[2J[0;0H[?25h"
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
    lt=""
    while [ "$t" ] ; do
        lt="$ct"
        ct="${t%${t#?}}"
        t="${t#?}"

        ce="${e%${e#?}}"
        e="${e#?}"

        case "$ce" in
            "$ct")
                newcolor="[0;32m"
                ;;
            "")
                newcolor="[0;37m"
                ;;
            *)
                newcolor="[0;31m"
            ;;
        esac

        [ "$lt" = " " ] && {
            next_word=${t%% *}
                    [ "$i" -gt "$((startcol - ${#next_word}))" ]  && {
                line=$((line+1))
                draw="${draw}[${line};${startcol}H"
                i=0
            }
        }

        [ "$color" != "$newcolor" ] && {
            color="$newcolor"
            draw="${draw}$newcolor"
            [ "$color" = "[0;37m" ] && cpos="${line};$((i+$startcol))"
        }


        [ "$color" = "[0;31m" ] && {
            [ "$ce" = " " ] && draw="${draw}_" || draw="${draw}$ce"
        } || {
            draw="$draw$ct"
        }

        i=$((i+1))
    done
    printf "%s[${cpos}H[?25h" "$draw"
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
    [ ! -z "$start" ] && printf "[s[$((areay-1));${areax}H[0m%s[u" "$(typr_get_time)"
}

typr_calculate_wpm () {
    printf "%s" "$((${#entered_text}*60000000000/(time_ns*5)))"
}

typr_show_results () {
    printf "[2J[?25l"

    now="$(date +%s%N)"
    time_ns=$((now-start))

    words="$(set -- $text ; printf "%s" "$#")"
    wpm="$(typr_calculate_wpm)"
    acc="$(typr_calculate_acc)"

    printf "[%s;${areax}H%s" \
        "${areay}" "[0;37mwpm" \
        "$((areay+1))" "[0m$wpm" \
        "$((areay+2))" "[0;37macc" \
        "$((areay+3))" "[0m$acc" \
        "$((areay+4))" "[0;37mtime" \
        "$((areay+5))" "[0m$(typr_get_time)" \
        "$((areay+6))" "[0;37mwords" \
        "$((areay+7))" "[0m$words"
}

typr_generate_text () {
    wordcount=100
    text="$(printf "%s " $(printf "%s\n" $words | shuf -r -n $wordcount))"
    text="${text% }"
}


typr_draw_loop () {
    while true; do
        typr_draw_time
    done
}

typr_start_timer () {
    start="$(date +%s%N)"
    typr_draw_loop &
    draw_pid="$!"
    export start draw_pid
}

typr_calculate_acc () {
    [ "$total_kp" != "0" ] && printf "%s%%" "$(((100*correct_kp)/total_kp))" || printf "%s" "0%"
}

typr_update_acc () {
    c=$1
    total_kp=$((total_kp+1))

    i=0
    t="$text"
    while [ "$i" -lt "$((${#entered_text}-1))" ]; do
        i=$((i+1))
        t="${t#?}" # remove first letter
    done
    correct_c=${t%${t#?}}

    [ "$c" = "$correct_c" ] && correct_kp=$((correct_kp+1))
    export correct_kp total_kp
}

typr_main () {
    total_kp=0
    correct_kp=0
    export correct_kp total_kp

    #fstart=$(date +%s%N)
    while true; do
        typr_draw_text

        # calculate performance
        #fend=$(date +%s%N)
        #msperframe=$(((fend-fstart)/1000000))
        #printf "[0;0H%6s" "$msperframe"

        c="$(tty_readc)"
        #fstart=$(date +%s%N)
        case "$c" in
            ''|'') break;;
            '')
                entered_text="${entered_text%?}"
                ;;
                " "|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|0|1|2|3|4|5|6|7|8|9|,|.|\?|\"|\'|!|-)
                [ -z "$start" ] && typr_start_timer

                entered_text="$entered_text$c"
                typr_update_acc "$c"
                ;;
        esac

        [ "${#entered_text}" = "${#text}" ] && break
    done
    kill "$draw_pid"

    typr_show_results

    while true; do
        case "$(tty_readc)" in
            ''|'') break;;
        esac
    done
}

typr_init () {
    set -- $(stty size)
    cols="$2"
    lines="$1"

    areax=$((cols / 3))
    areay=$((lines / 3))
    tty_init
    typr_generate_text
    typr_main
    tty_cleanup
}

typr_init
