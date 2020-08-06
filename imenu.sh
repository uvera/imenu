#!/bin/bash

################################################
## build menus and GUIs with just instantMENU ##
################################################

# needs instantmenu, fzf and dialog

if [ "$1" = "cli" ]; then
    shift 1
    USECLIMENU="True"
fi

climenu() {
    [ -e /tmp/climenu ] || [ -n "$USECLIMENU" ]
}

case "$1" in
-c) # confirmation dialog with prompt $2
    if [ "$2" = "-i" ]; then
        shift 1
        YESCOLOR=":ryes"
        NOCOLOR=":gno"
    else
        YESCOLOR=":gyes"
        NOCOLOR=":rno"
    fi
    if ! climenu; then
        if ! [ ${#2} -ge 30 ]; then
            ANSWER=$(echo "$YESCOLOR
$NOCOLOR" | instantmenu -w 300 -bw 4 -c -l 100 -p "${2:-confirm} ")
        else
            ANSWER=$(echo "$YESCOLOR
$NOCOLOR" | instantmenu -bw 4 -c -l 100 -p "${2:-confirm} ")
        fi
    else
        #dialog confirm promt that returns exit status

        confirm() {
            DIATEXT=${1:-are you sure about that?}
            dialog --yesno "$DIATEXT" 700 600
        }

        if confirm "$2"; then
            ANSWER="yes"
        else
            ANSWER="no"
        fi
    fi

    if grep -q "yes" <<<"${ANSWER}"; then
        exit 0
    else
        exit 1
    fi
    ;;
-C) # confirmation dialog with prompt from stdin
    PROMPT="$(cat /dev/stdin | sed 's/^/> /g')"
    PROMPT="$PROMPT
> 
:gyes
:rno"
    if ! climenu; then
        while ! grep -Eq '^(:gyes|:rno|forcequit)$' <<<"$ANSWER"; do
            ANSWER=$(echo "$PROMPT" | sed 's/^$/> /g' | sed 's/^yes$/:gyes/g' |
                sed 's/^no$/:rno/g' | instantmenu -bw 4 -c -l 100 -q 'confirmation')
        done
    else
        while ! grep -Eq '^(yes|no|forcequit)$' <<<"$ANSWER"; do
            PROMPTHEIGHT=$(wc -l <<<"$PROMPT")
            ANSWER=$(echo "$PROMPT" | sed 's/^:.//g' | fzf --header-lines "$(expr $PROMPTHEIGHT - 2)" --layout reverse --prompt "? ")
        done
    fi

    if grep -q "yes" <<<"${ANSWER}"; then
        exit 0
    else
        exit 1
    fi

    ;;
-w)
    # waiting thingy
    echo "> $2
:g OK" | instantmenu -h -1 -l 20 -c -bw 4 -w -1 -q "loading..." &
    ;;
-e)
    # error message
    echo "> $2
:r OK" | instantmenu -h -1 -l 20 -c -bw 4 -w -1 -q "error"
    ;;

-P) # password dialog
    if ! climenu; then
        echo "" | instantmenu -bw 4 -p "${2:-enter password}" -P -c -w 800
    else
        passwordbox() {
            unset user_input
            while [ -z "$user_input" ]; do
                #statements
                user_input=$(
                    dialog --passwordbox "${1:-enter password}" 700 700 \
                        3>&1 1>&2 2>&3 3>&-
                )
            done
            echo "$user_input"
        }
        passwordbox "${2:-enter password}"
    fi
    ;;
-i) # input dialog
    if ! climenu; then
        echo "" | instantmenu -bw 4 -q "${3:-enter to confirm}" -p "${2:-enter text}" -c -w 800 -I
    else
        textbox() {
            unset user_input
            while [ -z "$user_input" ]; do
                #statements
                user_input=$(
                    dialog --inputbox "${1:-enter text}" 700 700 \
                        3>&1 1>&2 2>&3 3>&-
                )
            done
            echo "$user_input"
        }
        textbox "${2:-enter text}"
    fi
    ;;
-m) # message
    PROMPT=$(sed 's/^/> /g' <<<$2)
    PROMPT="$PROMPT
>
OK"
    PROMPTHEIGHT=$(wc -l <<<"$PROMPT")

    if ! climenu; then
        echo "$PROMPT" | instantmenu -bw 4 -l 20 -c
    else
        echo "$PROMPT" | fzf --layout reverse --header-lines "$(expr $PROMPTHEIGHT - 1)" --prompt "- "
    fi
    ;;
-M) # message from stdin
    PROMPT="$(cat /dev/stdin | sed 's/^/> /g')"
    PROMPT="$PROMPT
>
OK"
    PROMPTHEIGHT=$(wc -l <<<"$PROMPT")

    if ! climenu; then
        echo "$PROMPT" | instantmenu -bw 4 -l 20 -c
    else
        echo "$PROMPT" | fzf --layout reverse --header-lines "$(expr $PROMPTHEIGHT - 1)" --prompt "- "
    fi
    ;;

-l) # choose item from list
    ASTDIN="$(cat /dev/stdin)"
    ANSWER=""

    while ! grep -q .. <<<"$ANSWER"; do
        if ! climenu; then
            ANSWER=$(echo "$ASTDIN" | instantmenu -i -bw 4 -p "${2:-choose}" -c -l 20)
        else
            if grep -q '^>' <<<"$ASTDIN"; then
                HEADERLINES=$(echo "$ASTDIN" | grep '^>' | wc -l)
                ANSWER=$(echo "$ASTDIN" | fzf --layout reverse --header-lines "$HEADERLINES" --prompt "${2:-choose}")
            else
                ANSWER=$(echo "$ASTDIN" | tac | fzf --prompt "${2:-choose}")
            fi
        fi
        if grep -q "forcequit" <<<"$ANSWER"; then
            exit 1
        fi

        if ! grep -Fxq "$ANSWER" <<<"$ASTDIN" || grep '^>' <<<"$ANSWER"; then
            ANSWER=""
        fi
    done

    echo "$ANSWER"
    ;;
-b)
    # checkbox functionality
    # lets user toggle
    AFILE=/tmp/listfile
    cat /dev/stdin >"$AFILE"
    cat /dev/stdin
    cat "$AFILE" | awk '{printf "%d %s\n", NR, $0}' | sed 's/^/[ ] /g' >"${AFILE}2"
    echo "OK" >>"${AFILE}2"
    cat "${AFILE}2" >"$AFILE"

    quit() {
        grep -a '^\[x' "$AFILE" | sed 's/^\[.\] [0-9]* //g'
        rm "$AFILE"
        exit
    }

    while ! [ "$ANSWER" = "OK" ]; do
        ANSWER="$(cat "$AFILE" | imenu -l 'type ok to confirm')"
        if grep -q '^OK' <<<"$ANSWER"; then
            quit
        fi
        if [ -n "$ANSWER" ]; then
            LINENUMBER=$(echo "$ANSWER" | grep -o '\[.\] [0-9]*' | grep -o '[0-9]*')
            if grep -q '^\[ \]' <<<"$ANSWER"; then
                NEWANSWER="$(echo "$ANSWER" | sed 's/^\[.\] /[x] /g' | sed 's|/|\\/|g')"
            else
                NEWANSWER="$(echo "$ANSWER" | sed 's/^\[.\] /[ ] /g' | sed 's|/|\\/|g')"
            fi
            sed -i "s/^\[.\] $LINENUMBER[^0-9][^0-9]*.*/$NEWANSWER/g" "$AFILE"
        fi
    done

    ;;

esac
