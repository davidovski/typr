#!/bin/sh

words="the be of and a to in he have it that for they i with as not on she at by this we you do but from or which one would all will there say who make when can more if no man out other so what time up go about than into could state only new year some take come these know see use get like then first any work now may such give over think most even find day also after way many must look before great back through long where much should well people down own just because good each those feel seem how high too place little world very still nation hand old life tell write become here show house both between need mean call develop under last right move thing general school never same another begin while number part turn real leave might want point form off child few small since against ask late home interest large person end open public follow during present without again hold govern around possible head consider word program problem however lead system set order eye plan run keep face fact group play stand increase early course change help line"

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
    y="${areay}"
    startcol=${areax}

    printf "[?25l"
    printf "%s\n" "$text" | while IFS= read -r line; do
        printf "%s" "[${y};${startcol}H[0;37m${line}"
        y=$((y+1))
    done
    printf "[${areay};${startcol}H[?25h"

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

typr_calculate_raw_wpm () {
    printf "%s" "$((${#entered_text}*60000000000/(time_ns*5)))"
}

typr_calculate_acc () {
    [ "$total_kp" != "0" ] && printf "%s" "$(((100*correct_kp)/total_kp))" || printf "%s" "0"
}


typr_show_results () {
    printf "[2J[?25l"

    now="$(date +%s%N)"
    time_ns=$((now-start))

    wc="$(set -- $text ; printf "%s" "$#")"
    raw_wpm="$(typr_calculate_raw_wpm)"
    acc="$(typr_calculate_acc)"
    wpm="$(((acc*raw_wpm) / 100))"

    printf "[%s;${areax}H%s" \
        "${areay}" "[0;37mwpm" \
        "$((areay+1))" "[0m$wpm" \
        "$((areay+2))" "[0;37macc" \
        "$((areay+3))" "[0m${acc}%" \
        "$((areay+4))" "[0;37mtime" \
        "$((areay+5))" "[0m$(typr_get_time)" \
        "$((areay+6))" "[0;37mraw" \
        "$((areay+7))" "[0m$raw_wpm"
}

typr_wrap_text () {
    t="$text"
    line=""
    lt=""
    while [ "$t" ] ; do
        lt="$ct"
        ct="${t%${t#?}}"
        t="${t#?}"

        [ "$lt" = " " ] && {
            next_word=${t%% *}
            [ "${#line}" -gt "$((areax - ${#next_word}))" ] && {
                printf "%s\n" "${line}"
                line=""
            }
        }
        line="${line}${ct}"
    done
}

typr_generate_text () {
    wordcount=100
    text="$(printf "%s " $(printf "%s\n" $words | shuf -r -n $wordcount))"
    text="${text% }"
    text="$(typr_wrap_text)"
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

typr_update_acc () {
    t="$current_line"
    e="$entered_line"
    while [ "$e" ] ; do
        ct="${t%${t#?}}"
        t="${t#?}"

        ce="${e%${e#?}}"
        e="${e#?}"

        [ "$ct" = "$ce" ] && correct_kp=$((correct_kp+1))
        total_kp=$((total_kp+1)) 
    done
    export correct_kp total_kp
}

typr_redraw_line () {
    color="[0;37m"
    line=$((areay + current_line_no - 1))
    startcol=${areax}

    draw="[${line};${startcol}H${color}"

    i=0
    t="$current_line"
    e="$entered_line"
    while [ "$t" ] ; do
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

        [ "$color" != "$newcolor" ] && {
            color="$newcolor"
            draw="${draw}$newcolor"
        }


        [ "$color" = "[0;31m" ] && {
            [ "$ce" = " " ] && draw="${draw}_" || draw="${draw}$ce"
        } || {
            draw="$draw$ct"
        }
    done
    printf "%s[${line};$((${#entered_line} + startcol))H[?25h" "$draw"
}

typr_new_line () {
        [ ! -z  "$entered_text" ] && entered_text="$entered_text"$'\n'
        entered_text="${entered_text}${entered_line}"
        typr_update_acc

        entered_line=""

        current_line_no=$((current_line_no+1))
        current_line="$(typr_get_text_line $current_line_no)"
        typr_redraw_line
}

typr_add_letter () {
    c="$1"
    [ -z "$start" ] && typr_start_timer

    entered_line="$entered_line$c"

    typr_redraw_line

    [ "${#entered_line}" = "${#current_line}" ] && {
        typr_new_line
    }

}

typr_del_letter () {
    [ -z "$entered_line" ] && prev=true || prev=false

    entered_line="${entered_line%?}"
    typr_redraw_line

    $prev && [ "$current_line_no" -gt "1" ] && {
        # move back one line in entered
        current_line_no=$((current_line_no-1))
        current_line="$(typr_get_text_line $current_line_no)"

        entered_line="$(typr_get_text_line $current_line_no "$entered_text")"
        entered_line="${entered_line%?}"
        entered_text="$(typr_remove_last_line "$entered_text")"
        typr_redraw_line
    }

}

# removes the last line, ignoring trailing whitespace
#
typr_remove_last_line() {
    t="${1%$'\n'}"
    printf "%s" "${1%$'\n'}" | while IFS= read -r line; do
        printf "%s\n" "$line"
    done
}

typr_get_text_line() {
    n="$1" t="${2:-$text}"
    case "$n" in
        ""|*[!0-9]*) return 1;;
    esac

    i=0

    printf "%s\n" "$t" | while IFS= read -r line; do
        i=$((i+1))
        [ "$i" = "$n" ] && printf "%s\n" "$line"
    done
}

typr_main () {
    entered_text=""
    entered_line=""
    start=

    total_kp=0
    correct_kp=0
    export correct_kp total_kp

    current_line_no=1
    current_line="$(typr_get_text_line $current_line_no)"

    printf "[2J"
    typr_draw_text
    while true; do

        c="$(tty_readc)"
        case "$c" in
            ''|'') break;;
            '')
                typr_del_letter
                ;;
                " "|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|0|1|2|3|4|5|6|7|8|9|,|.|\?|\"|\'|!|-)
                    typr_add_letter "$c"
                ;;
            '	')
                kill "$draw_pid"
                typr_generate_text
                typr_main
                return
                ;;
        esac
        [ "$((${#entered_text}+${#entered_line}+2))" = "${#text}" ] && break
    done
    kill "$draw_pid"

    entered_line="$entered_line "
    typr_new_line
    typr_show_results

    while true; do
        case "$(tty_readc)" in
            ''|''|q) break;;
            '	') 
                typr_generate_text
                typr_main
                return
                ;;
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
