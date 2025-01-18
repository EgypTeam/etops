if [ "$1" == "system" ] | [ "$1" == "" ]; then
    etops system start ${@:2}
else
    etops service start $*
fi
